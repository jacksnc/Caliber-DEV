import { PGlite } from "@electric-sql/pglite";
import { gateway } from "../supabase/functions/caliber-gateway/handler.ts";
import type { AuthBudget } from "../supabase/functions/caliber-gateway/auth_budget.ts";
import {
  type FoodPhotoProposer,
  parseProposal,
} from "../supabase/functions/caliber-gateway/food_photo.ts";

function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const config = {
  supabaseURL: "https://project.invalid",
  publishableKey: "server-only-fixture",
};
const subject = "11111111-1111-4111-8111-111111111111";
// A JPEG's base64 always begins "/9j/"; the rest only has to be valid base64.
const image = "/9j/" + "A".repeat(400);
const session = "Bearer header.payload.signature";
const authUser: typeof fetch = (url, init) => {
  assert(String(url) === "https://project.invalid/auth/v1/user");
  assert(new Headers(init?.headers).get("authorization") === session);
  return Promise.resolve(new Response(JSON.stringify({ id: subject })));
};
const request = (body: unknown, authorization: string | null = session) =>
  new Request(
    "https://gateway.invalid/functions/v1/caliber-gateway/ai/food-photo",
    {
      method: "POST",
      headers: authorization ? { authorization } : {},
      body: JSON.stringify(body),
    },
  );
const proposal: FoodPhotoProposer = () =>
  Promise.resolve({
    items: [{ name: "white rice, cooked", grams: 180, confidence: "medium" }],
  });

Deno.test("model replies are accepted only in the expected shape, without nutrients", () => {
  const good = parseProposal(
    JSON.stringify({
      items: [{ name: " Banana ", grams: 118.4, confidence: "high" }],
    }),
  );
  assert(good?.items[0].name === "Banana" && good.items[0].grams === 118);
  assert(parseProposal("not json") === null);
  assert(
    parseProposal(
      JSON.stringify({ items: [{ name: "x", grams: 0, confidence: "high" }] }),
    ) === null,
  );
  assert(
    parseProposal(
      JSON.stringify({ items: [{ name: "x", grams: 10, confidence: "sure" }] }),
    ) === null,
  );
  assert(
    parseProposal(
      JSON.stringify({
        items: Array(9).fill({ name: "x", grams: 10, confidence: "low" }),
      }),
    ) ===
      null,
  );
  assert(parseProposal(JSON.stringify({ items: [] }))?.items.length === 0);
});

Deno.test("photo estimates stay off until a proposer is configured", async () => {
  const handler = gateway(config, authUser);
  const response = await handler(request({ image }));
  assert(response.status === 503);
  assert((await response.json()).error === "not_configured");
});

Deno.test("photo estimates need a verified session, a JPEG and budget before the provider runs", async () => {
  const counter = { calls: 0 };
  const calls = () => counter.calls;
  const counting: FoodPhotoProposer = (data) => {
    counter.calls += 1;
    assert(data === image);
    return proposal(data);
  };
  const spent: string[] = [];
  const budget: AuthBudget = {
    consume: (route, identifier) => {
      spent.push(`${route}:${identifier}`);
      return Promise.resolve({ allowed: true, retryAfter: 0 });
    },
  };
  const handler = gateway(config, authUser, budget, counting);

  assert((await handler(request({ image }, null))).status === 401);
  assert(
    (await handler(request({ image: "iVBORw0KGgo" + "A".repeat(400) })))
      .status === 400,
  );
  assert((await handler(request({ image, extra: true }))).status === 400);
  assert(calls() === 0 && spent.length === 0);

  const response = await handler(request({ image }));
  assert(response.status === 200);
  const body = await response.json();
  assert(body.items[0].grams === 180 && !("calories" in body.items[0]));
  assert(body.model === "claude-opus-5-5");
  assert(calls() === 1 && spent[0] === `food-photo:${subject}`);

  const rejectedSession = gateway(
    config,
    () => Promise.resolve(new Response("{}", { status: 401 })),
    budget,
    counting,
  );
  assert((await rejectedSession(request({ image }))).status === 401);
  assert(calls() === 1);
});

Deno.test("an exhausted budget answers 429 without calling the provider", async () => {
  let called = false;
  const handler = gateway(
    config,
    authUser,
    { consume: () => Promise.resolve({ allowed: false, retryAfter: 42 }) },
    () => {
      called = true;
      return proposal("");
    },
  );
  const response = await handler(request({ image }));
  assert(
    response.status === 429 && response.headers.get("retry-after") === "42",
  );
  assert(!called);
});

Deno.test("a declined or failed estimate is reported, not invented", async () => {
  const approved: AuthBudget = {
    consume: () => Promise.resolve({ allowed: true, retryAfter: 0 }),
  };
  const declined = gateway(
    config,
    authUser,
    approved,
    () => Promise.resolve(null),
  );
  assert((await declined(request({ image }))).status === 422);
  const failing = gateway(
    config,
    authUser,
    approved,
    () => Promise.reject(new Error("down")),
  );
  assert((await failing(request({ image }))).status === 502);
});

Deno.test("migration 005 gives each account three photo estimates per five minutes", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      GRANT USAGE ON SCHEMA auth TO authenticated,anon;`,
    );
    for (
      const migration of [
        "001_foundation.sql",
        "002_auth_guard.sql",
        "003_auth_guard_route_cleanup.sql",
        "004_account_lifecycle.sql",
        "005_food_photo_budget.sql",
      ]
    ) {
      await db.exec(
        await Deno.readTextFile(
          new URL("../supabase/migrations/" + migration, import.meta.url),
        ),
      );
    }
    const guard = "a".repeat(64), one = "b".repeat(64), two = "c".repeat(64);
    await db.query(
      "UPDATE caliber_auth_guard SET enabled=true,secret_sha256=encode(sha256(convert_to($1,'UTF8')),'hex')",
      [guard],
    );
    const spend = async (hash: string) =>
      (await db.query<{ r: { allowed: boolean } }>(
        "SELECT caliber_auth_budget('food-photo',$1,$2) r",
        [hash, guard],
      )).rows[0].r.allowed;
    for (let i = 0; i < 4; i++) assert((await spend(one)) === (i < 3));
    assert(await spend(two));
    // Earlier routes keep their limits.
    for (let i = 0; i < 3; i++) {
      const allowed = (await db.query<{ r: { allowed: boolean } }>(
        "SELECT caliber_auth_budget('recovery-request',$1,$2) r",
        [one, guard],
      )).rows[0].r.allowed;
      assert(allowed === (i < 2));
    }
  } finally {
    await db.close();
  }
});
