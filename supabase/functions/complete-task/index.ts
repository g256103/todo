import {
  authenticate,
  canonicalUuid,
  corsHeaders,
  dbErrorCode,
  defaultDependencies,
  errorResponse,
  HandlerDependencies,
  invalidRequestResponse,
  isRecord,
  isUuid,
  isValidIdempotencyKey,
  jsonResponse,
  parseJson,
} from "../_shared.ts";

const allowedFields = new Set(["challenge_task_id", "idempotency_key"]);
const errorStatuses: Record<string, number> = {
  unauthorized: 401,
  invalid_uuid: 422,
  invalid_idempotency_key: 422,
  task_not_found: 404,
  challenge_not_found: 404,
  challenge_already_success: 409,
  challenge_already_failed: 409,
  challenge_not_in_progress: 409,
  deadline_exceeded: 409,
  idempotency_key_reused: 409,
  complete_task_conflict: 409,
  temporary_unavailable: 503,
};

export type CompleteTaskRequest = {
  challenge_task_id: string;
  idempotency_key: string;
};

export function validateRequest(
  value: unknown,
): CompleteTaskRequest | { errorCode: string } {
  if (!isRecord(value)) return { errorCode: "invalid_request" };
  for (const field of Object.keys(value)) {
    if (!allowedFields.has(field)) return { errorCode: "unknown_field" };
  }
  if (
    !isUuid(value.challenge_task_id) ||
    value.challenge_task_id !== value.challenge_task_id.toLowerCase()
  ) {
    return { errorCode: "invalid_uuid" };
  }
  if (!isValidIdempotencyKey(value.idempotency_key)) {
    return { errorCode: "invalid_idempotency_key" };
  }
  return {
    challenge_task_id: canonicalUuid(value.challenge_task_id),
    idempotency_key: value.idempotency_key,
  };
}

export function mapDatabaseError(error: unknown): {
  errorCode: string;
  status: number;
} {
  const errorCode = dbErrorCode(error);
  return { errorCode, status: errorStatuses[errorCode] ?? 500 };
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

  const client = await authenticate(request, dependencies);
  if (client instanceof Response) return client;
  const body = await parseJson(request);
  if (body instanceof Response) return body;
  const validated = validateRequest(body);
  if ("errorCode" in validated) {
    return invalidRequestResponse(validated.errorCode, request);
  }

  const { data, error } = await client.rpc("complete_task", {
    p_challenge_task_id: validated.challenge_task_id,
    p_idempotency_key: validated.idempotency_key,
  });
  if (error) {
    const mapped = mapDatabaseError(error);
    return errorResponse(mapped.errorCode, mapped.status, request);
  }
  if (!isRecord(data)) return errorResponse("internal_error", 500, request);
  return jsonResponse(data, 200, request);
}

if (import.meta.main) Deno.serve((request) => handleRequest(request));
