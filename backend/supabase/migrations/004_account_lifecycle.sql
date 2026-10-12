-- Add bounded recovery budgets without resetting existing sign-in/refresh counters.
ALTER TABLE public.caliber_auth_buckets DROP CONSTRAINT caliber_auth_buckets_route_check;
ALTER TABLE public.caliber_auth_buckets ADD CONSTRAINT caliber_auth_buckets_route_check
  CHECK (route IN ('sign-in','refresh','recovery-request','recovery-verify'));

-- Account access alone does not authorize uploading personal logs or photos.
CREATE TABLE public.caliber_account_consent (
  subject uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  version text NOT NULL CHECK (version='account-access-v1'),
  accepted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(subject,version)
);
ALTER TABLE public.caliber_account_consent ENABLE ROW LEVEL SECURITY;
CREATE POLICY caliber_consent_owner ON public.caliber_account_consent
  FOR SELECT TO authenticated USING(subject=auth.uid());
REVOKE ALL ON public.caliber_account_consent FROM anon,authenticated;
GRANT SELECT ON public.caliber_account_consent TO authenticated;
CREATE FUNCTION public.caliber_accept_account_access(p_version text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $consent$
DECLARE who uuid:=auth.uid();
BEGIN
  IF who IS NULL OR NOT EXISTS (SELECT 1 FROM auth.users WHERE id=who) THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  IF p_version IS DISTINCT FROM 'account-access-v1' THEN RAISE EXCEPTION 'invalid_consent'; END IF;
  INSERT INTO public.caliber_account_consent(subject,version) VALUES(who,p_version)
    ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('accepted',true,'version',p_version);
END;
$consent$;
REVOKE ALL ON FUNCTION public.caliber_accept_account_access(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.caliber_accept_account_access(text) TO authenticated;

-- Keep retention cleanup under the route lock already held by this transaction.
-- Prevent cross-route lock cycles after an idle period; preserve existing grants.
CREATE OR REPLACE FUNCTION public.caliber_auth_budget(p_route text,p_identity_hash text,p_guard text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $budget$
DECLARE
  checked_at timestamptz;
  global_capacity numeric; identity_capacity numeric;
  global_tokens numeric; identity_tokens numeric;
  global_updated timestamptz; identity_updated timestamptz;
  wait_seconds integer;
BEGIN
  -- The anon key alone cannot spend a budget. This independent server-only guard
  -- grants no health-data access, user administration or arbitrary table access.
  IF p_guard IS NULL OR p_guard !~ '^[a-f0-9]{64}$' OR NOT EXISTS(
    SELECT 1 FROM public.caliber_auth_guard WHERE singleton AND enabled
      AND secret_sha256 = pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(p_guard,'UTF8')),'hex')
  ) THEN RAISE EXCEPTION 'auth_guard_unavailable'; END IF;
  IF p_route IS NULL OR p_route NOT IN ('sign-in','refresh','recovery-request','recovery-verify') OR
     p_identity_hash IS NULL OR p_identity_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid_auth_budget';
  END IF;
  global_capacity := CASE p_route WHEN 'sign-in' THEN 20 WHEN 'refresh' THEN 50 WHEN 'recovery-request' THEN 10 ELSE 20 END;
  identity_capacity := CASE p_route WHEN 'sign-in' THEN 5 WHEN 'refresh' THEN 10 WHEN 'recovery-request' THEN 2 ELSE 5 END;
  INSERT INTO public.caliber_auth_buckets(route,bucket,tokens,updated_at)
    VALUES(p_route,'global',global_capacity,pg_catalog.clock_timestamp()) ON CONFLICT DO NOTHING;
  -- Every instance locks the same route's global row first. No process-local cache
  -- or client clock can reset the budget, and simultaneous attempts cannot overspend.
  SELECT tokens,updated_at INTO global_tokens,global_updated FROM public.caliber_auth_buckets
    WHERE route=p_route AND bucket='global' FOR UPDATE;
  checked_at := pg_catalog.clock_timestamp();
  global_tokens := least(global_capacity,global_tokens + greatest(0,extract(epoch FROM checked_at-global_updated))*global_capacity/300);
  IF global_tokens < 1 THEN
    RETURN pg_catalog.jsonb_build_object('allowed',false,'retryAfter',greatest(1,ceil((1-global_tokens)*300/global_capacity)::integer));
  END IF;
  INSERT INTO public.caliber_auth_buckets(route,bucket,tokens,updated_at)
    VALUES(p_route,p_identity_hash,identity_capacity,checked_at) ON CONFLICT DO NOTHING;
  SELECT tokens,updated_at INTO identity_tokens,identity_updated FROM public.caliber_auth_buckets
    WHERE route=p_route AND bucket=p_identity_hash FOR UPDATE;
  identity_tokens := least(identity_capacity,identity_tokens + greatest(0,extract(epoch FROM checked_at-identity_updated))*identity_capacity/300);
  IF identity_tokens < 1 THEN
    wait_seconds := greatest(1,ceil((1-identity_tokens)*300/identity_capacity)::integer);
    RETURN pg_catalog.jsonb_build_object('allowed',false,'retryAfter',wait_seconds);
  END IF;
  UPDATE public.caliber_auth_buckets SET tokens=global_tokens-1,updated_at=greatest(checked_at,global_updated)
    WHERE route=p_route AND bucket='global';
  UPDATE public.caliber_auth_buckets SET tokens=identity_tokens-1,updated_at=greatest(checked_at,identity_updated)
    WHERE route=p_route AND bucket=p_identity_hash;
  -- Prune only the route already locked above, avoiding cross-route lock cycles.
  -- An idle route retains its old buckets until its next successful request.
  DELETE FROM public.caliber_auth_buckets WHERE route=p_route AND updated_at < checked_at-interval '24 hours';
  RETURN pg_catalog.jsonb_build_object('allowed',true,'retryAfter',0);
END;
$budget$;
