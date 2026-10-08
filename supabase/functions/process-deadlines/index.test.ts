import { handleRequest } from "./index.ts";

function request(options: {
  method?: string;
  authorization?: string;
} = {}): Request {
  return new Request("http://localhost/functions/v1/process-deadlines", {
    method: options.method ?? "POST",
    headers: {
      Authorization: options.authorization ?? "Bearer test-secret",
    },
  });
}

Deno.test("process-deadlines validates authorization and method", async () => {
  Deno.env.set("AUTO_START_CRON_SECRET", "test-secret");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");

  if (
    (await handleRequest(request({ method: "OPTIONS" }))).status !== 204
  ) {
    throw new Error("OPTIONS");
  }
  if (
    (await handleRequest(request({ method: "GET" }))).status !== 405
  ) {
    throw new Error("GET method");
  }
  if (
    (await handleRequest(request({ authorization: "Bearer invalid" })))
      .status !== 401
  ) {
    throw new Error("unauthorized");
  }

  const successRes = await handleRequest(request(), {
    process: async () => ({ data: 3, error: null }),
  });
  if (successRes.status !== 200) {
    throw new Error("expected 200");
  }
  const body = await successRes.json();
  if (body.processed_count !== 3) {
    throw new Error("expected 3 processed");
  }

  const errorRes = await handleRequest(request(), {
    process: async () => ({ data: null, error: { message: "db error" } }),
  });
  if (errorRes.status !== 503) {
    throw new Error("expected 503 on db error");
  }
});
