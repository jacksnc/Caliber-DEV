-- Read only. Run before migration 004; never display credentials or raw account data.
SELECT 'original journal tables exist' AS criterion,
  (SELECT count(*)=2 FROM pg_tables WHERE schemaname='public' AND tablename IN ('caliber_accounts','caliber_revisions')) AS passed
UNION ALL SELECT 'guard configured and enabled',
  EXISTS(SELECT 1 FROM public.caliber_auth_guard WHERE singleton AND enabled AND secret_sha256 IS NOT NULL)
UNION ALL SELECT 'consent migration not already applied', to_regclass('public.caliber_account_consent') IS NULL
UNION ALL SELECT 'existing guard RPC present', to_regprocedure('public.caliber_auth_budget(text,text,text)') IS NOT NULL
UNION ALL SELECT 'journal Auth foreign keys cascade',
  (SELECT count(*)=2 FROM pg_constraint WHERE contype='f' AND confrelid='auth.users'::regclass AND confdeltype='c'
    AND conrelid IN ('public.caliber_accounts'::regclass,'public.caliber_revisions'::regclass));
