import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedFields = new Set([
  "payment_id",
  "task_ids",
  "routine_ids",
  "idempotency_key",
]);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const errorStatuses: Record<string, number> = {
  unauthorized: 401,
  payment_not_found: 404,
  task_not_found: 404,
  routine_not_found: 404,
  payment_not_success: 409,
  payment_not_successful: 409,
  active_challenge_exists: 409,
  idempotency_key_reused: 409,
  no_tasks_selected: 422,
  invalid_uuid: 422,
  invalid_idempotency_key: 422,
  unknown_field: 422,
  challenge_creation_conflict: 409,
  temporary_unavailable: 503,
};

type CreateChallengeRequest = {
  payment_id: string;
  task_ids: string[];
  routine_ids: string[];
  idempotency_key: string;
};

type AuthenticatedClient = {
  auth: {
    getUser: () => Promise<{
      data: { user: unknown | null };
      error: unknown | null;
    }>;
  };
  rpc: (
    functionName: string,
    args: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: unknown | null }>;
};

type HandlerDependencies = {
  getClient: (request: Request) => AuthenticatedClient;
};

const defaultDependencies: HandlerDependencies = {
  getClient: (request) => {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error("Supabase environment is not configured");
    }

    return createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: request.headers.get("Authorization") ?? "",
        },
      },
    });
  },
};

function configuredOrigins(): Set<string> {
  const configured = Deno.env.get("CORS_ALLOWED_ORIGINS");
  const origins = configured
    ?.split(",")
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);

  return new Set(
    origins && origins.length > 0
      ? origins
      : ["http://127.0.0.1:3000", "http://localhost:3000"],
  );
}

export function corsHeaders(request: Request): Headers {
  const headers = new Headers({
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  });
  const origin = request.headers.get("Origin");

  if (origin && configuredOrigins().has(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
  }

  return headers;
}

function jsonResponse(
  body: unknown,
  status: number,
  request: Request,
): Response {
  const headers = corsHeaders(request);
  headers.set("Content-Type", "application/json");
  return new Response(JSON.stringify(body), { status, headers });
}

function errorResponse(
  errorCode: string,
  status: number,
  request: Request,
): Response {
  return jsonResponse({ error_code: errorCode }, status, request);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" && uuidPattern.test(value);
}

function isUuidArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => isUuid(item));
}

export function validateCreateChallengeRequest(
  value: unknown,
): CreateChallengeRequest | { errorCode: string } {
  if (!isRecord(value)) {
    return { errorCode: "invalid_request" };
  }

  for (const field of Object.keys(value)) {
    if (!allowedFields.has(field)) {
      return { errorCode: "unknown_field" };
    }
  }

  if (!isUuid(value.payment_id)) {
    return { errorCode: "invalid_uuid" };
  }
  if (!isUuidArray(value.task_ids)) {
    return { errorCode: "invalid_uuid" };
  }
  if (!isUuidArray(value.routine_ids)) {
    return { errorCode: "invalid_uuid" };
  }
  if (
    typeof value.idempotency_key !== "string" ||
    Array.from(value.idempotency_key).length < 1 ||
    Array.from(value.idempotency_key).length > 200
  ) {
    return { errorCode: "invalid_idempotency_key" };
  }
  if (value.task_ids.length === 0 && value.routine_ids.length === 0) {
    return { errorCode: "no_tasks_selected" };
  }

  return {
    payment_id: value.payment_id,
    task_ids: value.task_ids,
    routine_ids: value.routine_ids,
    idempotency_key: value.idempotency_key,
  };
}

function dbErrorCode(error: unknown): string {
  if (!isRecord(error)) {
    return "internal_error";
  }

  const message = error.message;
  return typeof message === "string" && errorStatuses[message]
    ? message
    : "internal_error";
}

export function mapDatabaseError(error: unknown): {
  errorCode: string;
  status: number;
} {
  const errorCode = dbErrorCode(error);
  return {
    errorCode,
    status: errorStatuses[errorCode] ?? 500,
  };
}

export async function handleRequest(
  request: Request,
  dependencies: HandlerDependencies = defaultDependencies,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(request) });
  }

  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", 405, request);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.match(/^Bearer\s+\S+$/i)) {
    return errorResponse("unauthorized", 401, request);
  }

  let client: AuthenticatedClient;
  try {
    client = dependencies.getClient(request);
  } catch {
    return errorResponse("internal_error", 500, request);
  }

  const { data: authData, error: authError } = await client.auth.getUser();
  if (authError || !authData.user) {
    return errorResponse("unauthorized", 401, request);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse("malformed_json", 400, request);
  }

  const validated = validateCreateChallengeRequest(body);
  if ("errorCode" in validated) {
    const status = validated.errorCode === "invalid_request" ? 400 : 422;
    return errorResponse(validated.errorCode, status, request);
  }

  const { data, error } = await client.rpc("create_challenge", {
    p_payment_id: validated.payment_id,
    p_task_ids: validated.task_ids,
    p_routine_ids: validated.routine_ids,
    p_idempotency_key: validated.idempotency_key,
  });

  if (error) {
    const mapped = mapDatabaseError(error);
    return errorResponse(mapped.errorCode, mapped.status, request);
  }

  return jsonResponse(data, 201, request);
}

if (import.meta.main) {
  Deno.serve((request) => handleRequest(request));
}
