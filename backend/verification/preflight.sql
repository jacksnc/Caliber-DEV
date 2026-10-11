-- Read schema metadata only. No user records or credentials are selected.
SELECT
  to_regclass('public.caliber_accounts') IS NULL AS accounts_name_available,
  to_regclass('public.caliber_revisions') IS NULL AS revisions_name_available,
  NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname IN ('caliber_push', 'caliber_pull')
  ) AS rpc_names_available,
  EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') AS authenticated_role_exists,
  EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') AS anon_role_exists,
  to_regprocedure('auth.uid()') IS NOT NULL AS auth_uid_exists,
  -- Review required fields before creating id-only rollback fixtures.
  (SELECT jsonb_agg(jsonb_build_object('column', column_name,
      'hasDefault', column_default IS NOT NULL) ORDER BY ordinal_position)
   FROM information_schema.columns
   WHERE table_schema = 'auth' AND table_name = 'users'
     AND is_nullable = 'NO') AS required_auth_fields;
