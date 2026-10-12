import { gateway } from "../supabase/functions/caliber-gateway/handler.ts";
import type { AuthBudget } from "../supabase/functions/caliber-gateway/auth_budget.ts";
const approvedBudget: AuthBudget = {
  consume: () => Promise.resolve({ allowed: true, retryAfter: 0 }),
};
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
      if (String(url).endsWith("/caliber_accept_account_access")) {
        return Promise.resolve(
          new Response(
            JSON.stringify({ accepted: true, version: "account-access-v1" }),
          ),
        );
      }
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
    approvedBudget,
  );
  const response = await handler(
    new Request("https://gateway.invalid/auth/sign-in", {
      method: "POST",
      body: JSON.stringify({
        email: "test@example.invalid",
        consentVersion: "account-access-v1",
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

const fictionalSessionToken = () => {
  const part = (value: unknown) =>
    btoa(JSON.stringify(value)).replaceAll("+", "-").replaceAll("/", "_")
      .replaceAll("=", "");
  return `${part({ alg: "ES256", typ: "JWT" })}.${
    part({
      session_id: "00000000-0000-4000-8000-000000000003",
      sub: "00000000-0000-4000-8000-000000000001",
    })
  }.fixtureSignature`;
};
Deno.test("sign-out revokes only the current session and sanitizes the empty upstream response", async () => {
  const token = fictionalSessionToken();
  let calls = 0;
  const handler = gateway(
    config,
    ((url, init) => {
      calls++;
      assert(
        String(url) === "https://project.invalid/auth/v1/logout?scope=local",
      );
      assert(init?.method === "POST" && init.redirect === "error");
      assert(
        new Headers(init.headers).get("authorization") === `Bearer ${token}`,
      );
      assert(new Headers(init.headers).get("apikey") === config.publishableKey);
      assert(init.body === undefined);
      return Promise.resolve(new Response(null, { status: 204 }));
    }) as typeof fetch,
  );
  const response = await handler(
    new Request("https://gateway.invalid/auth/sign-out", {
      method: "POST",
      headers: { authorization: `Bearer ${token}` },
      body: "{}",
    }),
  );
  const body = await response.text();
  assert(
    response.status === 200 && body === JSON.stringify({ signedOut: true }),
  );
  assert(response.headers.get("cache-control") === "no-store");
  assert(
    !body.includes(token) && !body.includes(config.publishableKey) &&
      calls === 1,
  );
});
Deno.test("sign-out denies absent, malformed, and legacy sessionless tokens without an upstream call", async () => {
  let calls = 0;
  const handler = gateway(
    config,
    (() => {
      calls++;
      return Promise.resolve(new Response(null, { status: 204 }));
    }) as typeof fetch,
  );
  const legacy = `${btoa("{}").replaceAll("=", "")}.${
    btoa(JSON.stringify({ sub: "00000000-0000-4000-8000-000000000001" }))
      .replaceAll("=", "")
  }.signature`;
  for (
    const authorization of [
      null,
      "Basic fixture",
      "Bearer",
      "Bearer invalid",
      `Bearer ${legacy}`,
      `Bearer ${"x".repeat(16384)}`,
    ]
  ) {
    const response = await handler(
      new Request("https://gateway.invalid/auth/sign-out", {
        method: "POST",
        headers: authorization ? { authorization } : {},
        body: "{}",
      }),
    );
    assert(response.status === 401);
  }
  assert(calls === 0);
});
Deno.test("sign-out does not accept scope or session selection from the client", async () => {
  let calls = 0;
  const handler = gateway(
    config,
    (() => {
      calls++;
      return Promise.resolve(new Response(null, { status: 204 }));
    }) as typeof fetch,
  );
  for (
    const body of [{ scope: "global" }, { scope: "others" }, {
      sessionID: "other",
    }, { refreshToken: "private" }]
  ) {
    const response = await handler(
      new Request("https://gateway.invalid/auth/sign-out", {
        method: "POST",
        headers: { authorization: `Bearer ${fictionalSessionToken()}` },
        body: JSON.stringify(body),
      }),
    );
    assert(response.status === 400);
  }
  assert(calls === 0);
});
Deno.test("sign-out delegates authentication and discards provider failures and unexpected success bodies", async () => {
  for (
    const [upstream, expected] of [[401, 401], [403, 401], [500, 409], [
      200,
      502,
    ]]
  ) {
    const handler = gateway(
      config,
      (() =>
        Promise.resolve(
          new Response("sensitive-provider-body", { status: upstream }),
        )) as typeof fetch,
    );
    const response = await handler(
      new Request("https://gateway.invalid/auth/sign-out", {
        method: "POST",
        headers: { authorization: `Bearer ${fictionalSessionToken()}` },
        body: "{}",
      }),
    );
    const text = await response.text();
    assert(
      response.status === expected && !text.includes("sensitive") &&
        !text.includes("signedOut"),
    );
  }
});
