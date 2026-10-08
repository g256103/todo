import {
  authenticate,
  corsHeaders,
  dbErrorCode,
  defaultDependencies,
  errorResponse,
  HandlerDependencies,
  invalidRequestResponse,
  isRecord,
  isValidIdempotencyKey,
  jsonResponse,
  parseJson,
} from "../_shared.ts";

const allowedFields = new Set(["token", "idempotency_key"]);
const errorStatuses: Record<string, number> = {
  unauthorized: 401,
  invalid_token: 422,
  invalid_idempotency_key: 422,
  qr_not_found: 404,
  challenge_not_success: 409,
  qr_already_used: 409,
  idempotency_key_reused: 409,
  use_qr_conflict: 409,
  temporary_unavailable: 503,
};

export type UseQrRequest = {
  token: string;
  idempotency_key: string;
};

function isValidToken(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.trim().length > 0 &&
    value === value.trim() &&
    Array.from(value).length <= 200
  );
}

export function validateRequest(
  value: unknown,
): UseQrRequest | { errorCode: string } {
  if (!isRecord(value)) return { errorCode: "invalid_request" };
  for (const field of Object.keys(value)) {
    if (!allowedFields.has(field)) return { errorCode: "unknown_field" };
  }
  if (!isValidToken(value.token)) {
    return { errorCode: "invalid_token" };
  }
  if (!isValidIdempotencyKey(value.idempotency_key)) {
    return { errorCode: "invalid_idempotency_key" };
  }
  return {
    token: value.token,
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

  const { data, error } = await client.rpc("use_qr", {
    p_token: validated.token,
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
