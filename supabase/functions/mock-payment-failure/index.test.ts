import { handleRequest, mapDatabaseError, validateRequest } from "./index.ts";

const valid = {
  payment_id: "11111111-1111-4111-8111-111111111111",
  idempotency_key: "failure-key",
};

function request(
  body: unknown,
  options: { method?: string; authorization?: string } = {},
): Request {
  return new Request("http://localhost/functions/v1/mock-payment-failure", {
    method: options.method ?? "POST",
    headers: {
      Authorization: options.authorization ?? "Bearer token",
      "Content-Type": "application/json",
    },
    body: ["GET", "HEAD", "OPTIONS"].includes(options.method ?? "")
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
        data: overrides.rpcData ??
          { response: { payment: { status: "FAILED" } }, replayed: false },
        error: overrides.rpcError ?? null,
      }),
    }),
  };
}

Deno.test("failure common HTTP validation", async () => {
  if (
    (await handleRequest(request(null, { method: "OPTIONS" }), dependencies()))
      .status !== 204
  ) throw new Error("OPTIONS");
  if (
    (await handleRequest(request(valid, { method: "GET" }), dependencies()))
      .status !== 405
  ) throw new Error("method");
  if (
    (await handleRequest(request(valid, { authorization: "" }), dependencies()))
      .status !== 401
  ) throw new Error("auth");
  const malformed = new Request("http://localhost", {
    method: "POST",
    headers: { Authorization: "Bearer token" },
    body: "{",
  });
  if ((await handleRequest(malformed, dependencies())).status !== 400) {
    throw new Error("json");
  }
  if (
    (await handleRequest(request({ ...valid, extra: true }), dependencies()))
      .status !== 422
  ) throw new Error("unknown");
});

Deno.test("failure delegates input validation and maps RPC errors", async () => {
  const invalid = validateRequest({ ...valid, payment_id: "bad" });
  if (!("errorCode" in invalid) || invalid.errorCode !== "invalid_uuid") {
    throw new Error("uuid");
  }
  const response = await handleRequest(request(valid), dependencies());
  if (
    response.status !== 200 ||
    (await response.json()).payment.status !== "FAILED"
  ) throw new Error("failure");
  for (
    const [code, status] of [
      ["payment_not_found", 404],
      ["payment_not_pending", 409],
      ["idempotency_key_reused", 409],
      ["temporary_unavailable", 503],
    ] as const
  ) {
    if (mapDatabaseError({ message: code }).status !== status) {
      throw new Error(code);
    }
  }
});

Deno.test("failure returns mapped RPC error response", async () => {
  const response = await handleRequest(
    request(valid),
    dependencies({ rpcError: { message: "payment_not_pending" } }),
  );
  const body = await response.json();
  if (response.status !== 409 || body.error_code !== "payment_not_pending") {
    throw new Error("RPC mapping");
  }
});
