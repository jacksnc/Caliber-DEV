import { gateway } from "../supabase/functions/caliber-gateway/handler.ts";
import type { AuthBudget } from "../supabase/functions/caliber-gateway/auth_budget.ts";
import { PGlite } from "@electric-sql/pglite";
const assert = (value: unknown, note = "assertion failed") => {
  if (!value) throw new Error(note);
};
const config = {
  supabaseURL: "https://project.invalid",
  publishableKey: "anon-fixture",
  serviceRoleKey: "admin-fixture",
};
const one = "00000000-0000-4000-8000-000000000001",
  two = "00000000-0000-4000-8000-000000000002";
const approved: AuthBudget = {
  consume: () => Promise.resolve({ allowed: true, retryAfter: 0 }),
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status });
const request = (route: string, body: unknown, bearer = "fixture") =>
  new Request("https://gateway.invalid/" + route, {
    method: "POST",
    body: JSON.stringify(body),
    headers: { authorization: "Bearer " + bearer },
  });
Deno.test("consent is mandatory before sign-in, tied to authenticated subject, and blocks token return on RPC failure", async () => {
  let calls = 0;
  const handler = gateway(
    config,
    ((url) => {
      calls++;
      if (String(url).includes("grant_type=password")) {
        return Promise.resolve(
          json({
            access_token: "private-access",
            refresh_token: "private-refresh",
            user: { id: one },
            expires_in: 3600,
          }),
        );
      }
      if (String(url).includes("logout")) {
        return Promise.resolve(
          new Response(null, { status: 204 }),
        );
      }
      return Promise.resolve(json({ private: "must-not-escape" }, 500));
    }) as typeof fetch,
    approved,
  );
  assert(
    (await handler(
      request("auth/sign-in", {
        email: "a@example.invalid",
        password: "fixture",
      }),
    )).status === 400,
  );
  assert(calls === 0);
  const result = await handler(
    request("auth/sign-in", {
      email: "a@example.invalid",
      password: "fixture",
      consentVersion: "account-access-v1",
    }),
  );
  assert(result.status === 503 && calls === 3);
  assert(!(await result.text()).includes("private"));
  assert(
    (await handler(
      request("account/consent", {
        version: "account-access-v1",
        subject: two,
      }),
    )).status === 400,
  );
});
Deno.test("recovery request has identical safe responses for existing and absent email and independent budgets", async () => {
  for (const status of [200, 400, 404, 422]) {
    let route = "";
    const handler = gateway(
      config,
      ((url, init) => {
        assert(String(url).endsWith("/auth/v1/recover"));
        assert(init?.redirect === "error");
        assert(
          new Headers(init?.headers).get("apikey") === config.publishableKey,
        );
        return Promise.resolve(
          json({ error: "email-account-details" }, status),
        );
      }) as typeof fetch,
      {
        consume: (kind) => {
          route = kind;
          return Promise.resolve({ allowed: true, retryAfter: 0 });
        },
      },
    );
    const result = await handler(
      request("auth/recover", { email: "a@example.invalid" }),
    );
    assert(
      result.status === 202 &&
        await result.text() === '{"recoveryRequested":true}',
    );
    assert(
      route === "recovery-request" &&
        result.headers.get("cache-control") === "no-store",
    );
  }
});
Deno.test("recovery outage, throttle, invalid fields, and oversized input cannot bypass controls", async () => {
  let calls = 0;
  const http = (() => {
    calls++;
    return Promise.resolve(json({}, 500));
  }) as typeof fetch;
  const handler = gateway(config, http, {
    consume: () => Promise.resolve({ allowed: false, retryAfter: 150 }),
  });
  for (
    const body of [{ email: "" }, {
      email: "a@example.invalid",
      redirectTo: "https://evil.invalid",
    }]
  ) {
    assert((await handler(request("auth/recover", body))).status === 400);
  }
  const limited = await handler(
    request("auth/recover", { email: "a@example.invalid" }),
  );
  assert(
    limited.status === 429 && limited.headers.get("retry-after") === "150" &&
      calls === 0,
  );
  assert(
    (await gateway(config, http)(
      request("auth/recover", { email: "a@example.invalid" }),
    )).status === 503,
  );
  assert(calls === 0);
  assert(
    (await gateway(config, http, approved)(
      request("auth/recover", { email: "a@example.invalid" }),
    )).status === 503,
  );
});
Deno.test("valid recovery code updates password and revokes sessions without returning a session", async () => {
  const paths: string[] = [];
  const handler = gateway(
    config,
    ((url, init) => {
      const path = String(url);
      paths.push(path);
      const body = init?.body ? JSON.parse(String(init.body)) : null;
      if (path.endsWith("/verify")) {
        assert(body.type === "recovery" && body.token === "123456");
        return Promise.resolve(
          json({
            access_token: "private-access",
            refresh_token: "private-refresh",
            user: { id: one },
          }),
        );
      }
      if (path.endsWith("/user")) {
        assert(
          init?.method === "PUT" && body.password === "new-fixture-password",
        );
        return Promise.resolve(json({ id: one }));
      }
      assert(path.endsWith("logout?scope=global"));
      return Promise.resolve(new Response(null, { status: 204 }));
    }) as typeof fetch,
    approved,
  );
  const result = await handler(
    request("auth/reset-password", {
      email: "a@example.invalid",
      code: "123456",
      newPassword: "new-fixture-password",
    }),
  );
  assert(
    await result.text() === '{"passwordUpdated":true,"sessionsRevoked":true}' &&
      paths.length === 3,
  );
});
Deno.test("wrong recovery code never updates password; password refusal still cleans ephemeral session", async () => {
  for (const verified of [false, true]) {
    const paths: string[] = [];
    const handler = gateway(
      config,
      ((url) => {
        const path = String(url);
        paths.push(path);
        if (path.endsWith("/verify")) {
          return Promise.resolve(json(
            verified
              ? { access_token: "temporary", user: { id: one } }
              : { error: "secret-code" },
            verified ? 200 : 403,
          ));
        }
        if (path.includes("logout")) {
          return Promise.resolve(new Response(null, { status: 204 }));
        }
        return Promise.resolve(json({ reason: "password policy" }, 422));
      }) as typeof fetch,
      approved,
    );
    const result = await handler(
      request("auth/reset-password", {
        email: "a@example.invalid",
        code: "123456",
        newPassword: "fixture-password",
      }),
    );
    assert(result.status === (verified ? 409 : 401));
    assert(paths.length === (verified ? 3 : 1));
    assert(!(await result.text()).includes("secret-code"));
  }
});
Deno.test("delete rejects missing auth, wrong confirmation, caller target, and wrong password without admin access", async () => {
  let adminCalls = 0;
  const handler = gateway(
    config,
    ((url) => {
      const path = String(url);
      if (path.includes("/admin/")) adminCalls++;
      return Promise.resolve(
        path.endsWith("/user")
          ? json({ id: one, email: "a@example.invalid" })
          : json({ reason: "private" }, 403),
      );
    }) as typeof fetch,
    approved,
  );
  for (
    const body of [{ password: "fixture", confirmation: "NO" }, {
      password: "fixture",
      confirmation: "DELETE",
      subject: two,
    }]
  ) {
    assert((await handler(request("account/delete", body))).status === 400);
  }
  const body = { password: "wrong-fixture", confirmation: "DELETE" };
  assert(
    (await handler(
      new Request("https://gateway.invalid/account/delete", {
        method: "POST",
        body: JSON.stringify(body),
      }),
    )).status === 401,
  );
  assert((await handler(request("account/delete", body))).status === 401);
  assert(adminCalls === 0);
});
Deno.test("delete derives target only from verified user and matching password authentication", async () => {
  for (const matched of [true, false]) {
    const state = { deleted: false, cleaned: false };
    const handler = gateway(
      config,
      ((url, init) => {
        const path = String(url), headers = new Headers(init?.headers);
        if (path.endsWith("/user")) {
          assert(headers.get("apikey") === config.publishableKey);
          return Promise.resolve(json({ id: one, email: "a@example.invalid" }));
        }
        if (path.includes("grant_type=password")) {
          return Promise.resolve(
            json({ access_token: "reauth", user: { id: matched ? one : two } }),
          );
        }
        if (path.includes("logout")) {
          state.cleaned = true;
          return Promise.resolve(new Response(null, { status: 204 }));
        }
        assert(path.endsWith("/admin/users/" + one));
        assert(
          init?.method === "DELETE" &&
            headers.get("apikey") === config.serviceRoleKey,
        );
        assert(
          headers.get("authorization") === "Bearer " + config.serviceRoleKey,
        );
        assert(JSON.parse(String(init?.body)).should_soft_delete === false);
        state.deleted = true;
        return Promise.resolve(json({ id: one }));
      }) as typeof fetch,
      approved,
    );
    const result = await handler(
      request("account/delete", {
        password: "fixture",
        confirmation: "DELETE",
      }),
    );
    assert(
      result.status === (matched ? 200 : 401) && state.deleted === matched &&
        state.cleaned === !matched,
    );
    assert(!(await result.text()).includes(config.serviceRoleKey));
  }
});
Deno.test("failed admin deletion cleans reauth session and never acknowledges deletion", async () => {
  let cleaned = false;
  const handler = gateway(
    config,
    ((url) => {
      const path = String(url);
      if (path.endsWith("/user")) {
        return Promise.resolve(
          json({ id: one, email: "a@example.invalid" }),
        );
      }
      if (path.includes("grant_type=password")) {
        return Promise.resolve(
          json({ access_token: "reauth", user: { id: one } }),
        );
      }
      if (path.includes("logout")) {
        cleaned = true;
        return Promise.resolve(new Response(null, { status: 204 }));
      }
      return Promise.resolve(json({ storage: "private-owned-file" }, 500));
    }) as typeof fetch,
    approved,
  );
  const result = await handler(
    request("account/delete", { password: "fixture", confirmation: "DELETE" }),
  );
  assert(
    result.status === 409 && cleaned &&
      !(await result.text()).includes("private"),
  );
});
Deno.test("consent SQL enforces subject ownership, live-user checks, cascade deletion, and recovery budgets", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      GRANT USAGE ON SCHEMA auth TO authenticated,anon; INSERT INTO auth.users VALUES ('${one}'),('${two}');`,
    );
    for (
      const migration of [
        "001_foundation.sql",
        "002_auth_guard.sql",
        "003_auth_guard_route_cleanup.sql",
        "004_account_lifecycle.sql",
      ]
    ) {
      await db.exec(
        await Deno.readTextFile(
          new URL("../supabase/migrations/" + migration, import.meta.url),
        ),
      );
    }
    await db.exec(
      `SET ROLE authenticated; SET request.jwt.claim.sub='${one}';`,
    );
    await db.query("SELECT caliber_accept_account_access($1)", [
      "account-access-v1",
    ]);
    await db.query("SELECT caliber_accept_account_access($1)", [
      "account-access-v1",
    ]);
    assert(
      (await db.query("SELECT * FROM caliber_account_consent")).rows.length ===
        1,
    );
    await db.exec(`SET request.jwt.claim.sub='${two}';`);
    assert(
      (await db.query("SELECT * FROM caliber_account_consent")).rows.length ===
        0,
    );
    let rejected = false;
    try {
      await db.exec("DELETE FROM caliber_account_consent");
    } catch {
      rejected = true;
    }
    assert(rejected);
    await db.exec(
      `RESET ROLE; DELETE FROM auth.users WHERE id='${one}'; SET ROLE authenticated; SET request.jwt.claim.sub='${one}';`,
    );
    rejected = false;
    try {
      await db.query("SELECT caliber_accept_account_access($1)", [
        "account-access-v1",
      ]);
    } catch {
      rejected = true;
    }
    assert(
      rejected &&
        (await db.query("SELECT * FROM caliber_account_consent")).rows
            .length === 0,
    );
    await db.exec("RESET ROLE");
    const guard = "a".repeat(64), hash = "b".repeat(64);
    await db.query(
      "UPDATE caliber_auth_guard SET enabled=true,secret_sha256=encode(sha256(convert_to($1,'UTF8')),'hex')",
      [guard],
    );
    for (let i = 0; i < 3; i++) {
      const result = (await db.query<{ r: { allowed: boolean } }>(
        "SELECT caliber_auth_budget('recovery-request',$1,$2) r",
        [hash, guard],
      )).rows[0].r;
      assert(result.allowed === (i < 2));
    }
  } finally {
    await db.close();
  }
});
