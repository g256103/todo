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

const allowedFields = new Set(["catalog_item_id", "idempotency_key"]);
const catalogIds = new Set(["book_1000", "material_500", "cert_2000"]);

const errorStatuses: Record<string, number> = {
  unauthorized: 401,
  invalid_catalog_item: 422,
  invalid_idempotency_key: 422,
  insufficient_balance: 409,
  idempotency_key_reused: 409,
  purchase_points_conflict: 409,
  temporary_unavailable: 503,
};

export type PurchasePointsRequest = {
  catalog_item_id: string;
  idempotency_key: string;
};

export function validateRequest(
  value: unknown,
): PurchasePointsRequest | { errorCode: string } {
  if (!isRecord(value)) return { errorCode: "invalid_request" };
  for (const field of Object.keys(value)) {
    if (!allowedFields.has(field)) return { errorCode: "unknown_field" };
  }
  const catalogItemId = value.catalog_item_id;
  if (
    typeof catalogItemId !== "string" ||
    catalogItemId !== catalogItemId.trim() ||
    !catalogIds.has(catalogItemId)
  ) {
    return { errorCode: "invalid_catalog_item" };
  }
  if (!isValidIdempotencyKey(value.idempotency_key)) {
    return { errorCode: "invalid_idempotency_key" };
  }
  return {
    catalog_item_id: catalogItemId,
    idempotency_key: value.idempotency_key as string,
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

  const { data, error } = await client.rpc("purchase_points", {
    p_catalog_item_id: validated.catalog_item_id,
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
