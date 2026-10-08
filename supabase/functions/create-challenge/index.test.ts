import {
  handleRequest,
  mapDatabaseError,
  validateCreateChallengeRequest,
} from "./index.ts";

const paymentId = "11111111-1111-4111-8111-111111111111";
const taskId = "22222222-2222-4222-8222-222222222222";
const routineId = "33333333-3333-4333-8333-333333333333";

function validBody() {
  return {
    payment_id: paymentId,
    task_ids: [taskId],
    routine_ids: [],
    idempotency_key: "create-challenge-test",
  };
}

function request(
  body: unknown,
  options: { authorization?: string; method?: string } = {},
): Request {
  return new Request("http://localhost/functions/v1/create-challenge", {
    method: options.method ?? "POST",
    headers: {
      Authorization: options.authorization ?? "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: options.method === "OPTIONS" ? undefined : JSON.stringify(body),
  });
}

function mockDependencies(
  overrides: {
    user?: object | null;
    authError?: object | null;
    rpcData?: unknown;
    rpcError?: object | null;
  } = {},
) {
  return {
    getClient: () => ({
      auth: {
        getUser: async () => ({
          data: { user: overrides.user === undefined ? { id: "user" } : overrides.user },
          error: overrides.authError ?? null,
        }),
      },
      rpc: async () => ({
        data: overrides.rpcData ?? { challenge: { id: "challenge-id" }, challenge_tasks: [] },
        error: overrides.rpcError ?? null,
      }),
    }),
  };
}

Deno.test("未認証のAuthorizationは401", async () => {
  const response = await handleRequest(
    request(validBody(), { authorization: "" }),
    mockDependencies(),
  );
  const body = await response.json();
  if (response.status !== 401 || body.error_code !== "unauthorized") {
    throw new Error("expected unauthorized");
  }
});

Deno.test("Supabase Authがユーザーを返さない場合は401", async () => {
  const response = await handleRequest(
    request(validBody()),
    mockDependencies({ user: null }),
  );
  if (response.status !== 401) {
    throw new Error("expected unauthorized");
  }
});

Deno.test("malformed JSONは400", async () => {
  const malformed = new Request("http://localhost/functions/v1/create-challenge", {
    method: "POST",
    headers: { Authorization: "Bearer test-token" },
    body: "{",
  });
  const response = await handleRequest(malformed, mockDependencies());
  const body = await response.json();
  if (response.status !== 400 || body.error_code !== "malformed_json") {
    throw new Error("expected malformed_json");
  }
});

Deno.test("unknown fieldは422", async () => {
  const response = await handleRequest(
    request({ ...validBody(), extra: true }),
    mockDependencies(),
  );
  const body = await response.json();
  if (response.status !== 422 || body.error_code !== "unknown_field") {
    throw new Error("expected unknown_field");
  }
});

Deno.test("payment_id不正は422", () => {
  const result = validateCreateChallengeRequest({
    ...validBody(),
    payment_id: "not-a-uuid",
  });
  if (!("errorCode" in result) || result.errorCode !== "invalid_uuid") {
    throw new Error("expected invalid_uuid");
  }
});

Deno.test("task_ids不正は422", () => {
  const result = validateCreateChallengeRequest({
    ...validBody(),
    task_ids: [taskId, "not-a-uuid"],
  });
  if (!("errorCode" in result) || result.errorCode !== "invalid_uuid") {
    throw new Error("expected invalid_uuid");
  }
});

Deno.test("routine_ids不正は422", () => {
  const result = validateCreateChallengeRequest({
    ...validBody(),
    routine_ids: "not-an-array",
  });
  if (!("errorCode" in result) || result.errorCode !== "invalid_uuid") {
    throw new Error("expected invalid_uuid");
  }
});

Deno.test("idempotency_keyなしは422", () => {
  const body = validBody();
  delete (body as Partial<typeof body>).idempotency_key;
  const result = validateCreateChallengeRequest(body);
  if (!("errorCode" in result) || result.errorCode !== "invalid_idempotency_key") {
    throw new Error("expected invalid_idempotency_key");
  }
});

Deno.test("idempotency_key長超過は422", () => {
  const result = validateCreateChallengeRequest({
    ...validBody(),
    idempotency_key: "x".repeat(201),
  });
  if (!("errorCode" in result) || result.errorCode !== "invalid_idempotency_key") {
    throw new Error("expected invalid_idempotency_key");
  }
});

Deno.test("task/routine両方空は422", async () => {
  const response = await handleRequest(
    request({ ...validBody(), task_ids: [], routine_ids: [] }),
    mockDependencies(),
  );
  const body = await response.json();
  if (response.status !== 422 || body.error_code !== "no_tasks_selected") {
    throw new Error("expected no_tasks_selected");
  }
});

Deno.test("正常RequestはRPC結果を201で返す", async () => {
  const rpcData = { challenge: { id: "challenge-id" }, challenge_tasks: [] };
  const response = await handleRequest(
    request({ ...validBody(), routine_ids: [routineId] }),
    mockDependencies({ rpcData }),
  );
  const body = await response.json();
  if (response.status !== 201 || JSON.stringify(body) !== JSON.stringify(rpcData)) {
    throw new Error("expected RPC response");
  }
});

Deno.test("DB error codeをHTTP statusへ変換する", () => {
  const mapped = mapDatabaseError({ message: "payment_not_successful" });
  if (mapped.status !== 409 || mapped.errorCode !== "payment_not_successful") {
    throw new Error("expected payment conflict mapping");
  }
});

Deno.test("CORS OPTIONSは204", async () => {
  const response = await handleRequest(
    request(null, { method: "OPTIONS" }),
    mockDependencies(),
  );
  if (response.status !== 204) {
    throw new Error("expected no content");
  }
});
