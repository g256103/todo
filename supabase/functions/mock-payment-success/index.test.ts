import { handleRequest, mapDatabaseError, validateRequest } from "./index.ts";

const paymentId = "ABCDEFAB-CDEF-4ABC-8ABC-ABCDEFABCDEF";
const valid = { payment_id: paymentId, idempotency_key: "payment-key" };

function request(
  body: unknown,
  options: { method?: string; authorization?: string } = {},
): Request {
  return new Request("http://localhost/functions/v1/mock-payment-success", {
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
  overrides: {
    rpcData?: unknown;
    rpcError?: object | null;
    user?: object | null;
  } = {},
) {
  return {
    getClient: () => ({
      auth: {
        getUser: async () => ({
          data: { user: overrides.user ?? { id: "u" } },
          error: null,
        }),
      },
      rpc: async () => ({
        data: overrides.rpcData ??
          { response: { payment: { status: "SUCCESS" } }, replayed: false },
        error: overrides.rpcError ?? null,
      }),
    }),
  };
}

Deno.test("success common HTTP validation", async () => {
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

Deno.test("success validates UUID and canonicalizes it", () => {
  const result = validateRequest(valid);
  if ("errorCode" in result || result.payment_id !== paymentId.toLowerCase()) {
    throw new Error("uuid");
  }
  for (const id of ["not-uuid", "", null]) {
    const invalid = validateRequest({ ...valid, payment_id: id });
    if (!("errorCode" in invalid) || invalid.errorCode !== "invalid_uuid") {
      throw new Error("invalid uuid");
    }
  }
});

Deno.test("success calls RPC, returns 200, and maps DB errors", async () => {
  const response = await handleRequest(request(valid), dependencies());
  if (
    response.status !== 200 ||
    (await response.json()).payment.status !== "SUCCESS"
  ) throw new Error("success");
  for (
    const [code, status] of [
      ["payment_not_found", 404],
      ["payment_not_pending", 409],
      ["idempotency_key_reused", 409],
      ["temporary_unavailable", 503],
      ["other", 500],
    ] as const
  ) {
    if (mapDatabaseError({ message: code }).status !== status) {
      throw new Error(code);
    }
  }
});

Deno.test("success returns mapped RPC error response", async () => {
  const response = await handleRequest(
    request(valid),
    dependencies({ rpcError: { message: "temporary_unavailable" } }),
  );
  const body = await response.json();
  if (
    response.status !== 503 ||
    body.error_code !== "temporary_unavailable"
  ) throw new Error("RPC mapping");
});
