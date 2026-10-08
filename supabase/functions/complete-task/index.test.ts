import { handleRequest, mapDatabaseError, validateRequest } from "./index.ts";

const valid = {
  challenge_task_id: "c1111111-1111-4111-8111-111111111111",
  idempotency_key: "complete-key",
};

function request(
  body: unknown,
  options: { method?: string; authorization?: string } = {},
): Request {
  return new Request("http://localhost/functions/v1/complete-task", {
    method: options.method ?? "POST",
    headers: {
      Authorization: options.authorization ?? "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: (options.method ?? "POST") === "GET" ||
        (options.method ?? "POST") === "HEAD" ||
        (options.method ?? "POST") === "OPTIONS"
      ? undefined
      : JSON.stringify(body),
  });
}

function dependencies(
  overrides: { rpcData?: unknown; rpcError?: object | null } = {},
) {
  return {
    getClient: () => ({
      auth: {
        getUser: async () => ({ data: { user: { id: "u" } }, error: null }),
      },
      rpc: async () => ({
        data: overrides.rpcData ?? {
          result: "completed",
          challenge_task: {
            id: valid.challenge_task_id,
            challenge_id: "a1111111-1111-4111-8111-111111111111",
            status: "COMPLETED",
            completed_at: "2026-10-06T03:02:00Z",
          },
          challenge_status: "IN_PROGRESS",
        },
        error: overrides.rpcError ?? null,
      }),
    }),
  };
}

Deno.test("complete validates HTTP and request contract", async () => {
  if (
    (await handleRequest(request(null, { method: "OPTIONS" }), dependencies()))
      .status !== 204
  ) {
    throw new Error("OPTIONS");
  }
  if (
    (await handleRequest(request(valid, { method: "GET" }), dependencies()))
      .status !== 405
  ) {
    throw new Error("GET method");
  }
  if (
    (await handleRequest(
      request(valid, { authorization: "invalid" }),
      dependencies(),
    ))
      .status !== 401
  ) {
    throw new Error("unauthorized");
  }
  if (
    (await handleRequest(
      request({ ...valid, extra: true }),
      dependencies(),
    )).status !== 422
  ) {
    throw new Error("unknown_field");
  }
  if (
    (await handleRequest(
      request({ ...valid, challenge_task_id: "invalid" }),
      dependencies(),
    )).status !== 422
  ) {
    throw new Error("invalid_uuid");
  }
  if (
    (await handleRequest(
      request({ ...valid, idempotency_key: "" }),
      dependencies(),
    )).status !== 422
  ) {
    throw new Error("invalid_idempotency_key");
  }
});

Deno.test("complete handles success and hard errors", async () => {
  const successRes = await handleRequest(request(valid), dependencies());
  if (successRes.status !== 200) throw new Error("status not 200");
  const data = await successRes.json();
  if (data.result !== "completed" || data.challenge_status !== "IN_PROGRESS") {
    throw new Error("unexpected response data");
  }

  if (mapDatabaseError({ message: "task_not_found" }).status !== 404) {
    throw new Error("404");
  }
  if (mapDatabaseError({ message: "complete_task_conflict" }).status !== 409) {
    throw new Error("409 conflict");
  }
  if (mapDatabaseError({ message: "idempotency_key_reused" }).status !== 409) {
    throw new Error("409 idempotency");
  }
  if (mapDatabaseError({ message: "temporary_unavailable" }).status !== 503) {
    throw new Error("503");
  }

  const notFoundRes = await handleRequest(
    request(valid),
    dependencies({ rpcError: { message: "task_not_found" } }),
  );
  if (notFoundRes.status !== 404) throw new Error("task_not_found status");
});

Deno.test("complete maps soft RPC rejections to HTTP 200 result bodies", async () => {
  const deadlineRes = await handleRequest(
    request(valid),
    dependencies({ rpcError: { message: "deadline_exceeded" } }),
  );
  if (deadlineRes.status !== 200) throw new Error("deadline_exceeded status");
  const deadlineBody = await deadlineRes.json();
  if (deadlineBody.result !== "deadline_exceeded") {
    throw new Error("deadline_exceeded result");
  }
  if (
    deadlineBody.challenge_task !== undefined ||
    deadlineBody.challenge_status !== undefined
  ) {
    throw new Error("deadline_exceeded must not include task fields");
  }

  const mappedDeadline = mapDatabaseError({ message: "deadline_exceeded" });
  if (mappedDeadline.status !== 200) throw new Error("mapped deadline status");
  if (mappedDeadline.resultBody?.result !== "deadline_exceeded") {
    throw new Error("mapped deadline body");
  }

  for (
    const code of [
      "challenge_not_in_progress",
      "challenge_already_success",
      "challenge_already_failed",
    ]
  ) {
    const res = await handleRequest(
      request(valid),
      dependencies({ rpcError: { message: code } }),
    );
    if (res.status !== 200) throw new Error(`${code} status`);
    const body = await res.json();
    if (body.result !== "invalid_state" || body.error_code !== code) {
      throw new Error(`${code} body`);
    }
    if (
      body.challenge_task !== undefined || body.challenge_status !== undefined
    ) {
      throw new Error(`${code} must not include task fields`);
    }

    const mapped = mapDatabaseError({ message: code });
    if (mapped.status !== 200) throw new Error(`mapped ${code} status`);
    if (
      mapped.resultBody?.result !== "invalid_state" ||
      mapped.resultBody?.error_code !== code
    ) {
      throw new Error(`mapped ${code} body`);
    }
  }
});
