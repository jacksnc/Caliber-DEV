-- Shared DEV pre-login budgets. No health records or raw identifiers are stored.
-- Apply once, then configure the secret digest through the private setup transaction.
CREATE TABLE public.caliber_auth_guard (
  singleton boolean PRIMARY KEY CHECK(singleton),
  secret_sha256 text CHECK(secret_sha256 ~ '^[a-f0-9]{64}$'),
  enabled boolean NOT NULL DEFAULT false,
  CHECK(NOT enabled OR secret_sha256 IS NOT NULL)
);
INSERT INTO public.caliber_auth_guard(singleton) VALUES(true);
CREATE TABLE public.caliber_auth_buckets (
  route text NOT NULL CHECK(route IN ('sign-in','refresh')),
  bucket text NOT NULL CHECK(bucket = 'global' OR bucket ~ '^[a-f0-9]{64}$'),
  tokens numeric NOT NULL CHECK(tokens >= 0 AND tokens <= 50),
  updated_at timestamptz NOT NULL,
  PRIMARY KEY(route,bucket)
);
CREATE INDEX caliber_auth_bucket_expiry ON public.caliber_auth_buckets(updated_at);
ALTER TABLE public.caliber_auth_guard ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caliber_auth_buckets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.caliber_auth_guard,public.caliber_auth_buckets FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.caliber_auth_budget(p_route text,p_identity_hash text,p_guard text)
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
  IF p_route IS NULL OR p_route NOT IN ('sign-in','refresh') OR
     p_identity_hash IS NULL OR p_identity_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid_auth_budget';
  END IF;
  global_capacity := CASE WHEN p_route='sign-in' THEN 20 ELSE 50 END;
  identity_capacity := CASE WHEN p_route='sign-in' THEN 5 ELSE 10 END;
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
  -- Prune expired pseudonymous buckets on successful traffic. The global budget
  -- bounds new rows; at most 24 hours of stale rows remain during active use.
  DELETE FROM public.caliber_auth_buckets WHERE updated_at < checked_at-interval '24 hours';
  RETURN pg_catalog.jsonb_build_object('allowed',true,'retryAfter',0);
END;
$budget$;
REVOKE ALL ON FUNCTION public.caliber_auth_budget(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.caliber_auth_budget(text,text,text) TO anon;
