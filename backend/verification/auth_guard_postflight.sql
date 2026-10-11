-- Read-only: all rows must pass. No digest, raw identifier or counter value is selected.
WITH tables AS (
  SELECT c.oid,c.relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relname IN ('caliber_auth_guard','caliber_auth_buckets') AND c.relkind='r'
), command AS (
  SELECT p.oid,p.prosecdef,p.proconfig,p.proacl,p.proowner,p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='caliber_auth_budget' AND pg_get_function_identity_arguments(p.oid)='p_route text, p_identity_hash text, p_guard text'
)
SELECT 'guard tables have RLS and no client privileges' AS criterion,
  count(*)=2 AND coalesce(bool_and(relrowsecurity AND
    NOT has_table_privilege('anon',oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') AND
    NOT has_table_privilege('authenticated',oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')),false) AS passed FROM tables
UNION ALL
SELECT 'guard tables have no client policies',count(*)=0 FROM pg_policy WHERE polrelid IN (SELECT oid FROM tables)
UNION ALL
SELECT 'guard command is fixed-path definer and anon only',count(*)=1 AND coalesce(bool_and(
  prosecdef AND proconfig=ARRAY['search_path=""'] AND has_function_privilege('anon',oid,'EXECUTE') AND
  NOT has_function_privilege('authenticated',oid,'EXECUTE') AND NOT EXISTS(
    SELECT 1 FROM aclexplode(coalesce(proacl,acldefault('f',proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE')),false) FROM command
UNION ALL
SELECT 'guard is configured and enabled',count(*)=1 AND coalesce(bool_and(enabled AND secret_sha256 ~ '^[a-f0-9]{64}$'),false) FROM public.caliber_auth_guard
UNION ALL
SELECT 'retention is scoped to the locked route',count(*)=1 AND coalesce(bool_and(
  strpos(prosrc,'DELETE FROM public.caliber_auth_buckets WHERE route=p_route AND updated_at') > 0),false) FROM command;
