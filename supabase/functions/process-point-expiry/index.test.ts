import { handleRequest } from "./index.ts";

Deno.test("process-point-expiry rejects missing cron secret", async () => {
  const original = Deno.env.get("AUTO_START_CRON_SECRET");
  Deno.env.delete("AUTO_START_CRON_SECRET");
  Deno.env.delete("DEADLINES_CRON_SECRET");
  Deno.env.delete("POINT_EXPIRY_CRON_SECRET");
  try {
    const response = await handleRequest(
      new Request("http://localhost/functions/v1/process-point-expiry", {
        method: "POST",
        headers: { Authorization: "Bearer secret" },
      }),
    );
    if (response.status !== 401) throw new Error("expected 401");
  } finally {
    if (original) Deno.env.set("AUTO_START_CRON_SECRET", original);
  }
});

Deno.test("process-point-expiry returns expired_count", async () => {
  Deno.env.set("AUTO_START_CRON_SECRET", "cron-secret");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role");
  Deno.env.set("SUPABASE_URL", "http://localhost:54321");
  const response = await handleRequest(
    new Request("http://localhost/functions/v1/process-point-expiry", {
      method: "POST",
      headers: { Authorization: "Bearer cron-secret" },
    }),
    {
      process: async () => ({ data: 2, error: null }),
    },
  );
  if (response.status !== 200) throw new Error("status");
  const body = await response.json();
  if (body.expired_count !== 2) throw new Error("body");
});
