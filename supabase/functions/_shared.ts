import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export type AuthenticatedClient = {
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

export type HandlerDependencies = {
  getClient: (request: Request) => AuthenticatedClient;
};

export const defaultDependencies: HandlerDependencies = {
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

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function configuredOrigins(): Set<string> {
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

export function jsonResponse(
  body: unknown,
  status: number,
  request: Request,
): Response {
  const headers = corsHeaders(request);
  headers.set("Content-Type", "application/json");
  return new Response(JSON.stringify(body), { status, headers });
}

export function errorResponse(
  errorCode: string,
  status: number,
  request: Request,
): Response {
  return jsonResponse({ error_code: errorCode }, status, request);
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && uuidPattern.test(value);
}

export function canonicalUuid(value: string): string {
  return value.toLowerCase();
}

export function isValidIdempotencyKey(value: unknown): value is string {
  return (
    typeof value === "string" &&
    Array.from(value).length >= 1 &&
    Array.from(value).length <= 200 &&
    value.trim().length > 0 &&
    value === value.trim()
  );
}

export function dbErrorCode(error: unknown): string {
  if (!isRecord(error) || typeof error.message !== "string") {
    return "internal_error";
  }
  return error.message;
}

export function unwrapRpcResponse(data: unknown): {
  response: unknown;
  replayed: boolean;
} | null {
  if (
    !isRecord(data) || !("response" in data) ||
    typeof data.replayed !== "boolean"
  ) {
    return null;
  }
  return { response: data.response, replayed: data.replayed };
}

export async function authenticate(
  request: Request,
  dependencies: HandlerDependencies,
): Promise<AuthenticatedClient | Response> {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.match(/^Bearer\s+\S+$/i)) {
    return errorResponse("unauthorized", 401, request);
  }

  let client: AuthenticatedClient;
  try {
    client = dependencies.getClient(request);
    const { data, error } = await client.auth.getUser();
    if (error || !data.user) {
      return errorResponse("unauthorized", 401, request);
    }
  } catch {
    return errorResponse("internal_error", 500, request);
  }

  return client;
}

export async function parseJson(
  request: Request,
): Promise<unknown | Response> {
  try {
    return await request.json();
  } catch {
    return errorResponse("malformed_json", 400, request);
  }
}

export function invalidRequestResponse(
  validationError: string,
  request: Request,
): Response {
  return errorResponse(
    validationError,
    validationError === "invalid_request" ? 400 : 422,
    request,
  );
}
