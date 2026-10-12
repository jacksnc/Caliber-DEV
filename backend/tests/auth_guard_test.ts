import { DatabaseAuthBudget } from "../supabase/functions/caliber-gateway/auth_budget.ts";
import { gateway } from "../supabase/functions/caliber-gateway/handler.ts";
import { PGlite } from "@electric-sql/pglite";

function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const config = {
  supabaseURL: "https://project.invalid",
  publishableKey: "fixture-server-key",
};
const guardSecret = "a1".repeat(32);
const signin = (
  body = {
    email: "  TEST@example.invalid  ",
    consentVersion: "account-access-v1",
    password: "fictional",
  },
) =>
  new Request("https://gateway.invalid/auth/sign-in", {
    method: "POST",
    body: JSON.stringify(body),
  });

Deno.test("login budget is checked on the normalized identifier before Auth", async () => {
  let calls = 0;
  const handler = gateway(
    config,
    (() => {
      calls++;
      return Promise.resolve(new Response("discarded", { status: 400 }));
    }) as typeof fetch,
    {
      consume: (route, identifier) => {
        assert(
          route === "sign-in" && identifier === "test@example.invalid" &&
            calls === 0,
        );
        return Promise.resolve({ allowed: true, retryAfter: 0 });
      },
    },
  );
  assert((await handler(signin())).status === 409 && calls === 1);
});

Deno.test("exhausted and failed guards never call Auth and return safe retry responses", async () => {
  for (const mode of ["exhausted", "failed", "missing"]) {
    let calls = 0;
    const budget = mode === "missing" ? undefined : {
      consume: () =>
        mode === "failed"
          ? Promise.reject(new Error("fictional-private-error"))
          : Promise.resolve({ allowed: false, retryAfter: 60 }),
    };
    const handler = gateway(
      config,
      (() => {
        calls++;
        throw new Error("must not call Auth");
      }) as typeof fetch,
      budget,
    );
    const response = await handler(signin());
    assert(calls === 0 && response.headers.get("cache-control") === "no-store");
    assert(response.status === (mode === "exhausted" ? 429 : 503));
    assert(
      await response.text() === JSON.stringify({
        error: mode === "exhausted"
          ? "rate_limited"
          : "temporarily_unavailable",
      }),
    );
    if (mode === "exhausted") {
      assert(response.headers.get("retry-after") === "60");
    }
  }
});

Deno.test("private keyed buckets omit raw email and ignore forwarded IP headers", async () => {
  const bodies: string[] = [];
  const budget = new DatabaseAuthBudget(
    { ...config, guardSecret },
    ((url, init) => {
      assert(String(url).endsWith("/rest/v1/rpc/caliber_auth_budget"));
      assert(
        init?.redirect === "error" && init.signal &&
          new Headers(init.headers).get("apikey") === config.publishableKey,
      );
      bodies.push(String(init.body));
      return Promise.resolve(
        new Response(JSON.stringify({ allowed: true, retryAfter: 0 })),
      );
    }) as typeof fetch,
  );
  await budget.consume("sign-in", "test@example.invalid");
  await budget.consume("sign-in", "test@example.invalid");
  await budget.consume("refresh", "test@example.invalid");
  assert(!bodies.join().includes("test@example.invalid"));
  const first = JSON.parse(bodies[0]);
  assert(
    /^[a-f0-9]{64}$/.test(first.p_identity_hash) &&
      first.p_guard === guardSecret,
  );
  assert(first.p_identity_hash === JSON.parse(bodies[1]).p_identity_hash);
  assert(first.p_identity_hash !== JSON.parse(bodies[2]).p_identity_hash);
  const handler = gateway(
    config,
    (() => Promise.resolve(new Response("", { status: 400 }))) as typeof fetch,
    budget,
  );
  const req = signin();
  req.headers.set("x-forwarded-for", "spoofed");
  await handler(req);
  assert(JSON.parse(bodies[3]).p_identity_hash === first.p_identity_hash);
});

Deno.test("invalid guard configuration or RPC results fail closed", async () => {
  for (const secret of ["", "a".repeat(63), "a".repeat(65), "Z".repeat(64)]) {
    let failed = false;
    try {
      new DatabaseAuthBudget({ ...config, guardSecret: secret });
    } catch {
      failed = true;
    }
    assert(failed);
  }
  for (
    const data of [
      null,
      {},
      { allowed: "yes", retryAfter: 0 },
      { allowed: true, retryAfter: 1 },
      { allowed: false, retryAfter: 0 },
      { allowed: false, retryAfter: 301 },
    ]
  ) {
    const budget = new DatabaseAuthBudget(
      { ...config, guardSecret },
      (() =>
        Promise.resolve(new Response(JSON.stringify(data)))) as typeof fetch,
    );
    let failed = false;
    try {
      await budget.consume("refresh", "fixture-refresh");
    } catch {
      failed = true;
    }
    assert(failed);
  }
});

Deno.test("upstream throttling is sanitized without reflecting provider details", async () => {
  const handler = gateway(
    config,
    (() =>
      Promise.resolve(
        new Response("private-provider-detail", {
          status: 429,
          headers: { "retry-after": "untrusted" },
        }),
      )) as typeof fetch,
    { consume: () => Promise.resolve({ allowed: true, retryAfter: 0 }) },
  );
  const response = await handler(signin());
  assert(
    response.status === 429 && response.headers.get("retry-after") === "60",
  );
  assert(await response.text() === '{"error":"rate_limited"}');
});

Deno.test("oversized auth streams are cancelled before Auth or budget work", async () => {
  let cancelled = false, budgetCalls = 0;
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(8193));
    },
    cancel() {
      cancelled = true;
    },
  });
  const handler = gateway(
    config,
    (() => {
      throw new Error("must not call");
    }) as typeof fetch,
    {
      consume: () => {
        budgetCalls++;
        return Promise.resolve({ allowed: true, retryAfter: 0 });
      },
    },
  );
  const response = await handler(
    new Request("https://gateway.invalid/auth/sign-in", {
      method: "POST",
      body: stream,
    }),
  );
  assert(response.status === 413 && cancelled && budgetCalls === 0);
});

Deno.test("logout remains available without spending a pre-login budget", async () => {
  const part = (value: unknown) =>
    btoa(JSON.stringify(value)).replaceAll("=", "");
  const token = part({ alg: "ES256" }) + "." +
    part({ session_id: "00000000-0000-4000-8000-000000000001" }) + ".signature";
  const handler = gateway(
    config,
    (() =>
      Promise.resolve(new Response(null, { status: 204 }))) as typeof fetch,
  );
  const response = await handler(
    new Request("https://gateway.invalid/auth/sign-out", {
      method: "POST",
      headers: { authorization: "Bearer " + token },
      body: "{}",
    }),
  );
  assert(response.status === 200);
});

Deno.test("database budgets enforce private grants, capacities, refill and retention", async () => {
  const db = new PGlite();
  try {
    await db.exec("CREATE ROLE anon; CREATE ROLE authenticated;");
    await db.exec(
      await Deno.readTextFile(
        new URL("../supabase/migrations/002_auth_guard.sql", import.meta.url),
      ),
    );
    await db.exec(
      await Deno.readTextFile(
        new URL(
          "../supabase/migrations/003_auth_guard_route_cleanup.sql",
          import.meta.url,
        ),
      ),
    );
    await db.exec(`UPDATE public.caliber_auth_guard SET enabled=true,
      secret_sha256=encode(sha256(convert_to('${guardSecret}','UTF8')),'hex');`);
    const spend = (
      route = "sign-in",
      hash = "b".repeat(64),
      secret = guardSecret,
    ) =>
      db.query<{ result: { allowed: boolean; retryAfter: number } }>(
        "SELECT public.caliber_auth_budget($1,$2,$3) AS result",
        [route, hash, secret],
      );
    const result = async (...args: Parameters<typeof spend>) =>
      (await spend(...args)).rows[0].result;
    const grants = (await db.query<{ private: boolean }>(`SELECT NOT
      has_table_privilege('anon','public.caliber_auth_guard','SELECT') AND NOT
      has_table_privilege('authenticated','public.caliber_auth_buckets','SELECT') AND NOT
      has_function_privilege('authenticated','public.caliber_auth_budget(text,text,text)','EXECUTE') AND
      has_function_privilege('anon','public.caliber_auth_budget(text,text,text)','EXECUTE') AS private`))
      .rows[0];
    assert(grants.private);
    const catalog = await db.query<{ passed: boolean }>(
      await Deno.readTextFile(
        new URL("../verification/auth_guard_postflight.sql", import.meta.url),
      ),
    );
    assert(
      catalog.rows.length === 5 && catalog.rows.every((row) => row.passed),
    );
    await db.exec("SET ROLE anon");
    for (let i = 0; i < 5; i++) assert((await result()).allowed);
    const denied = await result();
    assert(
      !denied.allowed && denied.retryAfter >= 59 && denied.retryAfter <= 60,
    );
    for (let i = 0; i < 15; i++) {
      assert(
        (await result("sign-in", i.toString(16).padStart(64, "0"))).allowed,
      );
    }
    assert(!(await result("sign-in", "c".repeat(64))).allowed);
    // Separate refresh route is still available when the sign-in global bucket is empty.
    assert((await result("refresh")).allowed);
    let deniedSecret = false;
    try {
      await spend("refresh", "d".repeat(64), "e".repeat(64));
    } catch {
      deniedSecret = true;
    }
    assert(deniedSecret);
    await db.exec(
      "RESET ROLE; UPDATE public.caliber_auth_buckets SET updated_at=updated_at-interval '300 seconds';",
    );
    assert((await result()).allowed);
    await db.exec(
      "UPDATE public.caliber_auth_buckets SET updated_at=clock_timestamp()+interval '300 seconds',tokens=0;",
    );
    assert(!(await result()).allowed); // Backward time cannot grant free tokens.
    await db.exec(
      "UPDATE public.caliber_auth_buckets SET updated_at=clock_timestamp()-interval '25 hours';",
    );
    assert((await result("refresh", "f".repeat(64))).allowed);
    assert(
      (await db.query<{ n: number }>(
        "SELECT count(*)::integer AS n FROM public.caliber_auth_buckets WHERE route='refresh' AND updated_at < clock_timestamp()-interval '24 hours'",
      )).rows[0].n === 0,
    );
    assert(
      (await db.query<{ n: number }>(
        "SELECT count(*)::integer AS n FROM public.caliber_auth_buckets WHERE route='sign-in' AND updated_at < clock_timestamp()-interval '24 hours'",
      )).rows[0].n > 0,
    ); // Refresh must not lock/delete the other route's stale rows.
    assert((await result()).allowed);
    assert(
      (await db.query<{ n: number }>(
        "SELECT count(*)::integer AS n FROM public.caliber_auth_buckets WHERE updated_at < clock_timestamp()-interval '24 hours'",
      )).rows[0].n === 0,
    );
    await db.exec("UPDATE public.caliber_auth_guard SET enabled=false");
    let disabled = false;
    try {
      await spend();
    } catch {
      disabled = true;
    }
    assert(disabled);
  } finally {
    await db.close();
  }
});
