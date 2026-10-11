import { PGlite } from "@electric-sql/pglite";

// Exercise the same catalog query that will verify the hosted deployment.
// Deliberate RLS/permission regressions must turn its results red.
Deno.test("deployment catalog checks detect disabled RLS and public RPC access", async () => {
  const db = new PGlite();
  try {
    await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
      CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
        SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;`);
    await db.exec(
      await Deno.readTextFile(
        new URL("../supabase/migrations/001_foundation.sql", import.meta.url),
      ),
    );
    const sql = await Deno.readTextFile(
      new URL("../verification/postflight.sql", import.meta.url),
    );
    const check = async () =>
      (await db.query<{ criterion: string; passed: boolean }>(sql)).rows;
    const baseline = await check();
    if (baseline.length !== 6 || baseline.some((row) => !row.passed)) {
      throw new Error(JSON.stringify(baseline));
    }
    await db.exec(
      `ALTER TABLE public.caliber_revisions DISABLE ROW LEVEL SECURITY;
      GRANT EXECUTE ON FUNCTION public.caliber_pull(uuid,bigint,integer) TO PUBLIC;`,
    );
    const changed = await check();
    for (
      const criterion of [
        "two tables with RLS",
        "command execution restricted to authenticated",
      ]
    ) {
      if (
        changed.find((row) => row.criterion === criterion)?.passed !== false
      ) {
        throw new Error(`Failed to detect regression: ${criterion}`);
      }
    }
  } finally {
    await db.close();
  }
});

Deno.test("hosted owner fixture checks run twice and leave no fixture rows", async () => {
  const db = new PGlite();
  try {
    await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
      CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
        SELECT coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
          nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid $$;
      GRANT USAGE ON SCHEMA auth TO anon, authenticated;`);
    await db.exec(
      await Deno.readTextFile(
        new URL("../supabase/migrations/001_foundation.sql", import.meta.url),
      ),
    );
    const fixture = await Deno.readTextFile(
      new URL("../verification/owner_isolation.sql", import.meta.url),
    );
    for (let run = 0; run < 2; run++) {
      await db.exec(fixture);
      const rows = (await db.query<{ clean: boolean }>(`SELECT
        NOT EXISTS(SELECT 1 FROM auth.users) AND
        NOT EXISTS(SELECT 1 FROM public.caliber_accounts) AND
        NOT EXISTS(SELECT 1 FROM public.caliber_revisions) AS clean`)).rows;
      if (rows[0]?.clean !== true) {
        throw new Error("Fixture rows survived rollback");
      }
    }
  } finally {
    await db.close();
  }
});
