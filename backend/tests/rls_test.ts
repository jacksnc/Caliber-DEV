import { PGlite } from "@electric-sql/pglite";
function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const one = "00000000-0000-4000-8000-000000000001",
  two = "00000000-0000-4000-8000-000000000002";
const owner = "018f0000-0000-7000-8000-000000000011",
  device = "018f0000-0000-7000-8000-000000000012",
  entity = "018f0000-0000-7000-8000-000000000013";
const make = (n: number, base?: string) => ({
  operationID: `018f0000-0000-7000-8000-${n.toString().padStart(12, "0")}`,
  ownerID: owner,
  entityID: entity,
  namespace: "note",
  ...(base ? { baseRevision: base } : {}),
  deviceID: device,
  logicalClock: n,
  tombstone: false,
  payload: btoa(JSON.stringify({ text: "synthetic" })),
  resolves: [] as string[],
});
Deno.test("Postgres RLS, idempotency, conflict preservation, and cursor contracts", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      GRANT USAGE ON SCHEMA auth TO authenticated,anon; GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated,anon;
      INSERT INTO auth.users VALUES ('${one}'),('${two}');`,
    );
    await db.exec(
      await Deno.readTextFile(
        new URL("../supabase/migrations/001_foundation.sql", import.meta.url),
      ),
    );
    await db.exec(
      `SET ROLE authenticated; SET request.jwt.claim.sub='${one}';`,
    );
    const push = async (operations: unknown[], useOwner = owner) =>
      (await db.query<{ result: { operationID: string; cursor: number }[] }>(
        "SELECT public.caliber_push($1,$2::jsonb) AS result",
        [useOwner, JSON.stringify(operations)],
      )).rows[0].result;
    const root = make(1),
      left = make(2, root.operationID),
      right = { ...make(3, root.operationID), tombstone: true };
    const first = await push([root]);
    const repeat = await push([root]);
    assert(first[0].cursor === repeat[0].cursor);
    await push([left, right]);
    assert(
      (await db.query("SELECT * FROM public.caliber_revisions")).rows.length ===
        3,
    );
    let rejected = false;
    try {
      await push([{ ...root, payload: btoa("{}") }]);
    } catch {
      rejected = true;
    }
    assert(rejected, "collision must reject");
    rejected = false;
    try {
      await db.exec("DELETE FROM public.caliber_revisions");
    } catch {
      rejected = true;
    }
    assert(rejected, "direct delete must reject");
    const resolution = {
      ...make(4, root.operationID),
      resolves: [left.operationID, right.operationID],
    };
    await push([resolution]);
    // Device B edited a resolved branch offline. Device C's earlier merge arrives afterward.
    // All three leaves survive; rejecting the historical merge would deadlock C's durable outbox.
    const offlineChild = make(5, left.operationID);
    await push([offlineChild]);
    const historicalMerge = {
      ...make(6, root.operationID),
      resolves: [left.operationID, right.operationID],
    };
    await push([historicalMerge]);
    const leaves = (await db.query<{ operation_id: string }>(
      `SELECT operation_id FROM public.caliber_revisions r
      WHERE NOT EXISTS (SELECT 1 FROM public.caliber_revisions child WHERE
        child.envelope->>'baseRevision'=r.operation_id::text OR (child.envelope->'resolves') ? r.operation_id::text)`,
    )).rows;
    assert(
      leaves.length === 3 &&
        [resolution, offlineChild, historicalMerge].every((op) =>
          leaves.some((row) => row.operation_id === op.operationID)
        ),
      "historical resolution preserves concurrent branches",
    );
    const assertRejected = async (operations: unknown[], message: string) => {
      const before =
        (await db.query("SELECT * FROM public.caliber_revisions")).rows.length;
      let denied = false;
      try {
        await push(operations);
      } catch {
        denied = true;
      }
      assert(denied, message);
      assert(
        (await db.query("SELECT * FROM public.caliber_revisions")).rows
          .length === before,
        "rejected command must roll back all revisions",
      );
    };
    await assertRejected(
      [{ ...make(7), logicalClock: 9007199254740992 }],
      "unsafe JSON integer clock",
    );
    await assertRejected([{ ...make(7), logicalClock: -1 }], "negative clock");
    await assertRejected(
      [make(7, make(99).operationID)],
      "missing parent rejected",
    );
    await assertRejected(
      [{ ...make(7, left.operationID), logicalClock: 1 }],
      "parent logical clock must precede child",
    );
    await assertRejected(
      [{ ...make(7, left.operationID), entityID: device }],
      "cross-entity parent rejected",
    );
    await assertRejected([{
      ...make(7, left.operationID),
      namespace: "weight",
    }], "cross-namespace parent rejected");
    await assertRejected(
      [{ ...make(7), logicalClock: 1.5 }],
      "fractional clock",
    );
    await assertRejected([{
      ...make(7, root.operationID),
      resolves: [left.operationID, left.operationID],
    }], "duplicate resolution branch");
    await assertRejected([{
      ...make(7),
      resolves: [root.operationID, left.operationID],
    }], "resolution cannot consume ancestor and descendant");
    await assertRejected([{
      ...make(7, offlineChild.operationID),
      resolves: [resolution.operationID, historicalMerge.operationID],
    }], "base must be common to resolved branches");
    await assertRejected([make(7), {
      ...make(8),
      logicalClock: 9007199254740992,
    }], "whole batch rolls back after later invalid operation");
    for (const cursor of [-1, 9007199254740992, null]) {
      let denied = false;
      try {
        await db.query("SELECT public.caliber_pull($1,$2,100)", [
          owner,
          cursor,
        ]);
      } catch {
        denied = true;
      }
      assert(denied, "unsafe or absent cursor rejected");
    }
    const page =
      (await db.query<{ result: { changes: unknown[]; hasMore: boolean } }>(
        "SELECT public.caliber_pull($1,0,2) AS result",
        [owner],
      )).rows[0].result;
    assert(page.changes.length === 2 && page.hasMore);
    await db.exec(`SET request.jwt.claim.sub='${two}';`);
    assert(
      (await db.query("SELECT * FROM public.caliber_revisions")).rows.length ===
        0,
      "RLS cross-account read",
    );
    rejected = false;
    try {
      await push([make(5)]);
    } catch {
      rejected = true;
    }
    assert(rejected, "cross-owner push");
    rejected = false;
    try {
      await db.query("SELECT public.caliber_pull($1,0,100)", [owner]);
    } catch {
      rejected = true;
    }
    assert(rejected, "cross-owner pull");
    await db.exec("RESET ROLE; SET ROLE anon; SET request.jwt.claim.sub='';");
    rejected = false;
    try {
      await db.query("SELECT public.caliber_pull($1,0,100)", [owner]);
    } catch {
      rejected = true;
    }
    assert(rejected, "anonymous RPC");
  } finally {
    await db.close();
  }
});
