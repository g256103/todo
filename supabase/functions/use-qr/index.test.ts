import { handleRequest, mapDatabaseError, validateRequest } from "./index.ts";

const valid = {
  token: "a".repeat(64),
  idempotency_key: "use-qr-key",
};

function request(
  body: unknown,
  options: { method?: string; authorization?: string } = {},
): Request {
  return new Request("http://localhost/functions/v1/use-qr", {
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
          result: "used",
          qr_code: {
            id: "a1111111-1111-4111-8111-111111111111",
            challenge_id: "b1111111-1111-4111-8111-111111111111",
            status: "USED",
            used_at: "2026-10-08T02:00:00Z",
          },
        },
        error: overrides.rpcError ?? null,
      }),
    }),
  };
}

Deno.test("use-qr validates HTTP and request contract", async () => {
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
      request({ ...valid, token: "" }),
      dependencies(),
    )).status !== 422
  ) {
    throw new Error("invalid_token");
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

Deno.test("use-qr returns RPC success body on HTTP 200", async () => {
  const response = await handleRequest(request(valid), dependencies());
  if (response.status !== 200) throw new Error("status");
  const body = await response.json();
  if (body.result !== "used") throw new Error("result");
});

Deno.test("use-qr maps database errors to HTTP status", async () => {
  const cases: Array<[string, number]> = [
    ["qr_not_found", 404],
    ["qr_already_used", 409],
    ["idempotency_key_reused", 409],
    ["unauthorized", 401],
    ["temporary_unavailable", 503],
  ];
  for (const [code, status] of cases) {
    const mapped = mapDatabaseError({ message: code });
    if (mapped.errorCode !== code || mapped.status !== status) {
      throw new Error(`${code} -> ${mapped.status}`);
    }
  }
  if (mapDatabaseError({ message: "unknown_code" }).status !== 500) {
    throw new Error("500 fallback");
  }
});

Deno.test("validateRequest accepts trimmed token", () => {
  const parsed = validateRequest(valid);
  if ("errorCode" in parsed || parsed.token !== valid.token) {
    throw new Error("valid request");
  }
});
