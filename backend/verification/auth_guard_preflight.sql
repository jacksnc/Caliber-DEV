-- Read-only prerequisites for migration 002. Require every boolean to be true.
SELECT
  to_regclass('public.caliber_auth_guard') IS NULL AS configuration_name_available,
  to_regclass('public.caliber_auth_buckets') IS NULL AS budget_name_available,
  to_regclass('public.caliber_auth_bucket_expiry') IS NULL AS index_name_available,
  to_regprocedure('public.caliber_auth_budget(text,text,text)') IS NULL AS command_name_available,
  length(encode(sha256(convert_to('fictional readiness fixture','UTF8')),'hex'))=64 AS builtin_digest_available;
