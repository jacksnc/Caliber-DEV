import { gateway } from "../supabase/functions/caliber-gateway/handler.ts";
function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const config = {
  supabaseURL: "https://project.invalid",
  publishableKey: "server-only-fixture",
};
Deno.test("unconfigured insecure hosts are rejected", () => {
  let rejected = false;
  try {
    gateway({ ...config, supabaseURL: "http://project.invalid" });
  } catch {
    rejected = true;
  }
  assert(rejected);
});
Deno.test("sign-in forwards secrets only upstream and returns the session contract", async () => {
  const handler = gateway(
    config,
    ((url, init) => {
      assert(
        String(url) ===
          "https://project.invalid/auth/v1/token?grant_type=password",
      );
      assert(
        new Headers(init?.headers).get("apikey") === "server-only-fixture",
      );
      assert(init?.redirect === "error");
      return Promise.resolve(
        new Response(
          JSON.stringify({
            access_token: "test-access",
            refresh_token: "test-refresh",
            user: { id: "00000000-0000-4000-8000-000000000001" },
            expires_in: 3600,
          }),
        ),
      );
    }) as typeof fetch,
  );
  const response = await handler(
    new Request("https://gateway.invalid/auth/sign-in", {
      method: "POST",
      body: JSON.stringify({
        email: "test@example.invalid",
        password: "fixture-only",
      }),
    }),
  );
  const text = await response.text();
  assert(response.status === 200);
  assert(!text.includes(config.publishableKey));
  assert(!text.includes("fixture-only"));
  const data = JSON.parse(text);
  assert(data.accessToken === "test-access");
  assert(data.expiresAt > Date.now() / 1000 - 978307200);
});
Deno.test("unauthenticated sync never reaches upstream", async () => {
  const handler = gateway(
    config,
    (() => {
      throw new Error("must not call");
    }) as typeof fetch,
  );
  const response = await handler(
    new Request("https://gateway.invalid/sync/pull", {
      method: "POST",
      body: "{}",
    }),
  );
  assert(response.status === 401);
});
Deno.test("SQL and provider error bodies are discarded", async () => {
  const handler = gateway(
    config,
    (() =>
      Promise.resolve(
        new Response("sensitive fixture body", { status: 500 }),
      )) as typeof fetch,
  );
  const response = await handler(
    new Request("https://gateway.invalid/sync/pull", {
      method: "POST",
      headers: { authorization: "Bearer fixture" },
      body: JSON.stringify({ ownerID: "fixture", after: 0, limit: 100 }),
    }),
  );
  assert(response.status === 409);
  assert(!(await response.text()).includes("sensitive"));
});
Deno.test("methods, malformed JSON, unknown routes, and oversized batches are denied", async () => {
  const handler = gateway(
    config,
    (() => {
      throw new Error("must not call");
    }) as typeof fetch,
  );
  assert(
    (await handler(new Request("https://gateway.invalid/sync/pull"))).status ===
      405,
  );
  assert(
    (await handler(
      new Request("https://gateway.invalid/sync/pull", {
        method: "POST",
        body: "bad",
      }),
    )).status === 400,
  );
  assert(
    (await handler(
      new Request("https://gateway.invalid/admin/delete", {
        method: "POST",
        body: "{}",
      }),
    )).status === 404,
  );
  assert(
    (await handler(
      new Request("https://gateway.invalid/sync/push", {
        method: "POST",
        headers: { authorization: "Bearer fixture" },
        body: JSON.stringify({ ownerID: "x", operations: Array(101).fill({}) }),
      }),
    )).status === 400,
  );
});
