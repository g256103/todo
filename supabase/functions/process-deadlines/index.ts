import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared.ts";

export type ProcessDeadlinesDependencies = {
  process: () => PromiseLike<{ data: unknown; error: unknown | null }>;
};

function response(body: unknown, status: number, request: Request): Response {
  const headers = corsHeaders(request);
  headers.set("Content-Type", "application/json");
  return new Response(JSON.stringify(body), {
    status,
    headers,
  });
}

function hasValidCronAuthorization(
  request: Request,
  expected: string,
): boolean {
  const authorization = request.headers.get("Authorization");
  return authorization === `Bearer ${expected}`;
}

export async function handleRequest(
  request: Request,
  dependencies?: ProcessDeadlinesDependencies,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(request) });
  }
  if (request.method !== "POST") {
    return response({ error_code: "method_not_allowed" }, 405, request);
  }

  const cronSecret = Deno.env.get("DEADLINES_CRON_SECRET") ??
    Deno.env.get("AUTO_START_CRON_SECRET");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (
    !cronSecret ||
    !serviceRoleKey ||
    !hasValidCronAuthorization(request, cronSecret)
  ) {
    return response({ error_code: "unauthorized" }, 401, request);
  }

  const process = dependencies?.process ?? (() => {
    const url = Deno.env.get("SUPABASE_URL");
    if (!url) throw new Error("Supabase environment is not configured");
    const client = createClient(url, serviceRoleKey);
    return client.rpc("process_deadlines");
  });
  try {
    const { data, error } = await process();
    if (error) {
      console.error("process_deadlines RPC failed");
      return response({ error_code: "temporary_unavailable" }, 503, request);
    }
    return response({ processed_count: data }, 200, request);
  } catch {
    console.error("process-deadlines request failed");
    return response({ error_code: "temporary_unavailable" }, 503, request);
  }
}

if (import.meta.main) Deno.serve((request) => handleRequest(request));
