import { handleRequest, mapDatabaseError, validateRequest } from "./index.ts";

const valid = { amount: 1000, idempotency_key: "create-key" };

function request(
  body: unknown,
  options: { method?: string; authorization?: string } = {},
): Request {
  return new Request("http://localhost/functions/v1/mock-payment-create", {
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

function dependencies(overrides: {
  rpcData?: unknown;
  rpcError?: object | null;
  user?: object | null;
} = {}) {
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
          { response: { payment: { id: "p" } }, replayed: false },
        error: overrides.rpcError ?? null,
      }),
    }),
  };
}

Deno.test("create common HTTP validation", async () => {
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
  const unknown = await handleRequest(
    request({ ...valid, extra: true }),
    dependencies(),
  );
  if (
    unknown.status !== 422 ||
    (await unknown.json()).error_code !== "unknown_field"
  ) throw new Error("unknown");
});

Deno.test("create validates amount and key", () => {
  for (const amount of [99, 150, 5100, "1000", null]) {
    const result = validateRequest({ ...valid, amount });
    if (!("errorCode" in result) || result.errorCode !== "invalid_amount") {
      throw new Error("amount");
    }
  }
  for (const amount of [100, 5000, 1000.0, 1e3]) {
    const result = validateRequest({ ...valid, amount });
    if ("errorCode" in result) throw new Error("valid amount");
  }
  for (const key of ["", " ", " key", "key "]) {
    const result = validateRequest({ ...valid, idempotency_key: key });
    if (
      !("errorCode" in result) || result.errorCode !== "invalid_idempotency_key"
    ) throw new Error("key");
  }
});

Deno.test("create unwraps RPC response and maps replay", async () => {
  const first = await handleRequest(request(valid), dependencies());
  if (first.status !== 201 || (await first.json()).payment.id !== "p") {
    throw new Error("first");
  }
  const replay = await handleRequest(
    request(valid),
    dependencies({
      rpcData: { response: { payment: { id: "p" } }, replayed: true },
    }),
  );
  if (replay.status !== 200) throw new Error("replay");
  if (
    mapDatabaseError({ message: "payment_creation_conflict" }).status !== 409
  ) throw new Error("mapping");
});

Deno.test("create maps RPC errors to HTTP responses", async () => {
  const response = await handleRequest(
    request(valid),
    dependencies({ rpcError: { message: "payment_creation_conflict" } }),
  );
  const body = await response.json();
  if (
    response.status !== 409 ||
    body.error_code !== "payment_creation_conflict"
  ) throw new Error("RPC mapping");
});
