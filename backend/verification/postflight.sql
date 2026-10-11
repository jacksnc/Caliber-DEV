-- Read-only deployment checks. Run after foundation.sql commits.
WITH tables AS (
  SELECT c.oid, c.relname, c.relrowsecurity
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('caliber_accounts', 'caliber_revisions') AND c.relkind = 'r'
), commands AS (
  SELECT p.oid, p.proname, p.prosecdef, p.proconfig
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname IN ('caliber_push', 'caliber_pull')
), checks AS (
  SELECT 'two tables with RLS' AS criterion,
    count(*) = 2 AND coalesce(bool_and(relrowsecurity), false) AS passed FROM tables
  UNION ALL
  SELECT 'anonymous table access denied', count(*) = 2 AND coalesce(bool_and(
    NOT has_table_privilege('anon', oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
  ), false) FROM tables
  UNION ALL
  SELECT 'authenticated table access is read only', count(*) = 2 AND coalesce(bool_and(
    has_table_privilege('authenticated', oid, 'SELECT') AND
    NOT has_table_privilege('authenticated', oid, 'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
  ), false) FROM tables
  UNION ALL
  SELECT 'exactly two owner read policies', count(*) = 2 AND coalesce(bool_and(
    p.polcmd = 'r' AND p.polpermissive AND
    p.polroles = ARRAY[(SELECT oid FROM pg_roles WHERE rolname = 'authenticated')] AND
    pg_get_expr(p.polqual, p.polrelid) = '(subject = auth.uid())'
  ), false) FROM pg_policy p JOIN tables t ON t.oid = p.polrelid
  UNION ALL
  SELECT 'two commands with fixed definer search path', count(*) = 2 AND coalesce(bool_and(
    prosecdef AND proconfig = ARRAY['search_path=""']
  ), false) FROM commands
  UNION ALL
  SELECT 'command execution restricted to authenticated', count(*) = 2 AND coalesce(bool_and(
    has_function_privilege('authenticated', oid, 'EXECUTE') AND
    NOT has_function_privilege('anon', oid, 'EXECUTE') AND
    NOT EXISTS (SELECT 1 FROM aclexplode(coalesce(
      (SELECT proacl FROM pg_proc WHERE pg_proc.oid = commands.oid), acldefault('f',
      (SELECT proowner FROM pg_proc WHERE pg_proc.oid = commands.oid)))) a
      WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE')
  ), false) FROM commands
)
SELECT criterion, passed FROM checks ORDER BY criterion;
