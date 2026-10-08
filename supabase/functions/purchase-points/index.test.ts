import { handleRequest, mapDatabaseError, validateRequest } from "./index.ts";

const valid = {
  catalog_item_id: "book_1000",
  idempotency_key: "purchase-key",
};

function request(
  body: unknown,
  options: { method?: string } = {},
): Request {
  return new Request("http://localhost/functions/v1/purchase-points", {
    method: options.method ?? "POST",
    headers: {
      Authorization: "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: (options.method ?? "POST") === "OPTIONS"
      ? undefined
      : JSON.stringify(body),
  });
}

function dependencies() {
  return {
    getClient: () => ({
      auth: {
        getUser: async () => ({ data: { user: { id: "u" } }, error: null }),
      },
      rpc: async () => ({
        data: { result: "completed", available_points: 500 },
        error: null,
      }),
    }),
  };
}

Deno.test("purchase-points validates request", () => {
  const parsed = validateRequest(valid);
  if ("errorCode" in parsed || parsed.catalog_item_id !== "book_1000") {
    throw new Error("valid request");
  }
  if (!("errorCode" in validateRequest({ ...valid, catalog_item_id: "bad" }))) {
    throw new Error("invalid catalog");
  }
});

Deno.test("purchase-points maps insufficient_balance to 409", () => {
  const mapped = mapDatabaseError({ message: "insufficient_balance" });
  if (mapped.status !== 409 || mapped.errorCode !== "insufficient_balance") {
    throw new Error("status");
  }
});

Deno.test("purchase-points returns RPC payload on success", async () => {
  const response = await handleRequest(request(valid), dependencies());
  if (response.status !== 200) throw new Error("status");
  const body = await response.json();
  if (body.result !== "completed") throw new Error("body");
});
