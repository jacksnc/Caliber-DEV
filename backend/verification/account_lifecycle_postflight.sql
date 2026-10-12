-- Read-only checks. No passwords, tokens, digests, emails or journal payloads returned.
WITH t AS (SELECT * FROM pg_class WHERE oid=to_regclass('public.caliber_account_consent')),
  f AS (SELECT * FROM pg_proc WHERE oid=to_regprocedure('public.caliber_accept_account_access(text)'))
SELECT 'consent RLS and own-read policy' AS criterion,
  EXISTS(SELECT 1 FROM t WHERE relrowsecurity) AND
  (SELECT count(*)=1 AND bool_and(polcmd='r' AND pg_get_expr(polqual,polrelid)='(subject = auth.uid())')
   FROM pg_policy WHERE polrelid=to_regclass('public.caliber_account_consent')) AS passed
UNION ALL SELECT 'consent table grants private',
  NOT has_table_privilege('anon','public.caliber_account_consent','SELECT,INSERT,UPDATE,DELETE') AND
  has_table_privilege('authenticated','public.caliber_account_consent','SELECT') AND
  NOT has_table_privilege('authenticated','public.caliber_account_consent','INSERT,UPDATE,DELETE')
UNION ALL SELECT 'consent RPC fixed definer path and restricted execution',
  EXISTS(SELECT 1 FROM f WHERE prosecdef AND proconfig=ARRAY['search_path=""'] AND
    has_function_privilege('authenticated',oid,'EXECUTE') AND NOT has_function_privilege('anon',oid,'EXECUTE') AND
    NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(proacl,acldefault('f',proowner))) WHERE grantee=0))
UNION ALL SELECT 'consent cascades from Auth',
  EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.caliber_account_consent'::regclass AND
    confrelid='auth.users'::regclass AND confdeltype='c')
UNION ALL SELECT 'recovery routes and route-scoped pruning present',
  EXISTS(SELECT 1 FROM pg_proc WHERE oid='public.caliber_auth_budget(text,text,text)'::regprocedure
    AND prosrc LIKE '%recovery-request%' AND prosrc LIKE '%recovery-verify%' AND prosrc LIKE '%WHERE route=p_route AND updated_at%')
UNION ALL SELECT 'original journal constraints unchanged',
  (SELECT count(*)=2 FROM pg_constraint WHERE contype='f' AND confrelid='auth.users'::regclass AND confdeltype='c'
    AND conrelid IN ('public.caliber_accounts'::regclass,'public.caliber_revisions'::regclass));
