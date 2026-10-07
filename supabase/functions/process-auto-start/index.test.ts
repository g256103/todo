import { handleRequest } from "./index.ts";

const cronSecret = "cron-test-secret";
const serviceRoleKey = "service-role-test-secret";

const request = (authorization?: string, method = "POST") =>
  new Request("http://localhost/functions/v1/process-auto-start", {
    method,
    headers: authorization === undefined
      ? {}
      : { Authorization: authorization },
  });

function preserveEnvironment(
  names: string[],
  callback: () => Promise<void>,
): Promise<void> {
  const original = new Map(names.map((name) => [name, Deno.env.get(name)]));
  return callback().finally(() => {
    for (const [name, value] of original) {
      if (value === undefined) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  });
}

Deno.test("OPTIONS returns 204", async () => {
  const response = await handleRequest(request(undefined, "OPTIONS"));
  if (response.status !== 204) throw new Error("OPTIONS");
});

Deno.test("valid cron secret executes the RPC", async () => {
  await preserveEnvironment(
    ["AUTO_START_CRON_SECRET", "SUPABASE_SERVICE_ROLE_KEY"],
    async () => {
      Deno.env.set("AUTO_START_CRON_SECRET", cronSecret);
      Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
      let calls = 0;
      const response = await handleRequest(
        request(`Bearer ${cronSecret}`),
        {
          process: async () => {
            calls++;
            return { data: 2, error: null };
          },
        },
      );
      const body = await response.json();
      if (response.status !== 200 || body.started_count !== 2 || calls !== 1) {
        throw new Error("process");
      }
      const responseText = JSON.stringify(body);
      if (responseText.includes(serviceRoleKey)) {
        throw new Error("service role leaked");
      }
    },
  );
});

Deno.test("missing or malformed authorization returns 401", async () => {
  await preserveEnvironment([
    "AUTO_START_CRON_SECRET",
    "SUPABASE_SERVICE_ROLE_KEY",
  ], async () => {
    Deno.env.set("AUTO_START_CRON_SECRET", cronSecret);
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
    for (const authorization of [undefined, "Bearer", "Basic value"]) {
      if ((await handleRequest(request(authorization))).status !== 401) {
        throw new Error("authorization");
      }
    }
  });
});

Deno.test("wrong secret and missing secret return 401", async () => {
  await preserveEnvironment([
    "AUTO_START_CRON_SECRET",
    "SUPABASE_SERVICE_ROLE_KEY",
  ], async () => {
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
    if ((await handleRequest(request("Bearer wrong"))).status !== 401) {
      throw new Error("wrong secret");
    }
    Deno.env.set("AUTO_START_CRON_SECRET", cronSecret);
    Deno.env.delete("AUTO_START_CRON_SECRET");
    if ((await handleRequest(request(`Bearer ${cronSecret}`))).status !== 401) {
      throw new Error("missing cron secret");
    }
  });
});

Deno.test("RPC errors remain 503 without exposing secret values", async () => {
  await preserveEnvironment(
    ["AUTO_START_CRON_SECRET", "SUPABASE_SERVICE_ROLE_KEY"],
    async () => {
      Deno.env.set("AUTO_START_CRON_SECRET", cronSecret);
      Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey);
      const response = await handleRequest(
        request(`Bearer ${cronSecret}`),
        {
          process: async () => ({
            data: null,
            error: new Error("database failure"),
          }),
        },
      );
      const body = await response.text();
      if (
        response.status !== 503 || body.includes(serviceRoleKey) ||
        body.includes(cronSecret)
      ) {
        throw new Error("error response");
      }
    },
  );
});
