import { handleRequest, mapDatabaseError, validateRequest } from "./index.ts";

const valid = {
  challenge_id: "a1111111-1111-4111-8111-111111111111",
  idempotency_key: "start-key",
};

function request(
  body: unknown,
  options: { method?: string; authorization?: string } = {},
): Request {
  return new Request("http://localhost/functions/v1/start-challenge", {
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
          id: valid.challenge_id,
          payment_id: "22222222-2222-4222-8222-222222222222",
          amount: 1000,
          status: "IN_PROGRESS",
          auto_start_at: "2026-10-06T03:05:00Z",
          deadline: "2026-10-07T03:00:00Z",
          started_at: "2026-10-06T03:01:00Z",
          created_at: "2026-10-06T03:00:00Z",
        },
        error: overrides.rpcError ?? null,
      }),
    }),
  };
}

Deno.test("start validates HTTP and request contract", async () => {
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
    throw new Error("method");
  }
  if (
    (await handleRequest(request(valid, { authorization: "" }), dependencies()))
      .status !== 401
  ) {
    throw new Error("auth");
  }
  const invalid = validateRequest({ ...valid, challenge_id: "bad" });
  if (!("errorCode" in invalid) || invalid.errorCode !== "invalid_uuid") {
    throw new Error("uuid");
  }
  const uppercase = validateRequest({
    ...valid,
    challenge_id: valid.challenge_id.toUpperCase(),
  });
  if (!("errorCode" in uppercase) || uppercase.errorCode !== "invalid_uuid") {
    throw new Error("canonical uuid");
  }
});

Deno.test("start returns the server response", async () => {
  const response = await handleRequest(request(valid), dependencies());
  const body = await response.json();
  if (response.status !== 200 || body.status !== "IN_PROGRESS") {
    throw new Error("start");
  }
});

Deno.test("start maps database errors", async () => {
  const response = await handleRequest(
    request(valid),
    dependencies({ rpcError: { message: "deadline_exceeded" } }),
  );
  const body = await response.json();
  if (response.status !== 409 || body.error_code !== "deadline_exceeded") {
    throw new Error("mapping");
  }
  if (mapDatabaseError({ message: "challenge_not_found" }).status !== 404) {
    throw new Error("status");
  }
});
