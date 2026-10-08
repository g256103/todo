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
  unwrapRpcResponse,
} from "../_shared.ts";

const allowedFields = new Set(["amount", "idempotency_key"]);
const errorStatuses: Record<string, number> = {
  unauthorized: 401,
  invalid_amount: 422,
  invalid_idempotency_key: 422,
  unknown_field: 422,
  idempotency_key_reused: 409,
  payment_creation_conflict: 409,
  temporary_unavailable: 503,
};

export type CreateRequest = { amount: number; idempotency_key: string };

export function validateRequest(
  value: unknown,
): CreateRequest | { errorCode: string } {
  if (!isRecord(value)) return { errorCode: "invalid_request" };
  for (const field of Object.keys(value)) {
    if (!allowedFields.has(field)) return { errorCode: "unknown_field" };
  }
  if (
    typeof value.amount !== "number" ||
    !Number.isFinite(value.amount) ||
    !Number.isInteger(value.amount) ||
    value.amount < 100 ||
    value.amount > 5000 ||
    value.amount % 100 !== 0
  ) {
    return { errorCode: "invalid_amount" };
  }
  if (!isValidIdempotencyKey(value.idempotency_key)) {
    return { errorCode: "invalid_idempotency_key" };
  }
  return { amount: value.amount, idempotency_key: value.idempotency_key };
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

  const { data, error } = await client.rpc("mock_payment_create", {
    p_amount: validated.amount,
    p_idempotency_key: validated.idempotency_key,
  });
  if (error) {
    const mapped = mapDatabaseError(error);
    return errorResponse(mapped.errorCode, mapped.status, request);
  }

  const result = unwrapRpcResponse(data);
  if (!result) return errorResponse("internal_error", 500, request);
  return jsonResponse(result.response, result.replayed ? 200 : 201, request);
}

if (import.meta.main) Deno.serve((request) => handleRequest(request));
