-- Synthetic database authorization check. No password, identity or session is created.
-- Claims are simulated: this does NOT prove signed-token authentication.
-- All fixture rows roll back. Identity sequence gaps can remain.
BEGIN;
DO $fixture$
DECLARE
  first_subject uuid := 'c71dfb62-e139-4fca-afb6-8d29cda70261';
  second_subject uuid := 'fdc711c7-089d-4807-af2b-9b99ff72ef4a';
  first_owner uuid := '0199b000-1000-7000-8000-000000000001';
  second_owner uuid := '0199b000-1000-7000-8000-000000000009';
  root jsonb; left_branch jsonb; right_branch jsonb; merge jsonb; offline_child jsonb; historical_merge jsonb;
  initial_result jsonb; page jsonb; before_count bigint; denied boolean;
BEGIN
  IF current_setting('plpgsql.check_asserts') <> 'on' THEN
    RAISE EXCEPTION 'fixture_assertions_must_be_enabled';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE id IN (first_subject, second_subject)) OR
     EXISTS (SELECT 1 FROM public.caliber_accounts WHERE owner_id IN (first_owner, second_owner)) THEN
    RAISE EXCEPTION 'fixture_collision';
  END IF;
  INSERT INTO auth.users(id) VALUES (first_subject), (second_subject);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claim.sub', first_subject::text, true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub',first_subject,'role','authenticated')::text, true);
  root := jsonb_build_object(
    'operationID','0199b000-1000-7000-8000-000000000004', 'ownerID',first_owner,
    'entityID','0199b000-1000-7000-8000-000000000003', 'namespace','note',
    'deviceID','0199b000-1000-7000-8000-000000000002', 'logicalClock',1,
    'tombstone',false, 'resolves','[]'::jsonb,
    'payload',encode(convert_to('{"text":"fictional hosted fixture"}','UTF8'),'base64'));
  initial_result := public.caliber_push(first_owner,jsonb_build_array(root));
  ASSERT initial_result = public.caliber_push(first_owner,jsonb_build_array(root)), 'retry must be idempotent';
  ASSERT (SELECT count(*) FROM public.caliber_revisions) = 1, 'own direct read';
  left_branch := root || jsonb_build_object('operationID','0199b000-1000-7000-8000-000000000005',
    'baseRevision',root->>'operationID','logicalClock',2);
  right_branch := root || jsonb_build_object('operationID','0199b000-1000-7000-8000-000000000006',
    'baseRevision',root->>'operationID','logicalClock',3,'tombstone',true);
  PERFORM public.caliber_push(first_owner,jsonb_build_array(left_branch,right_branch));
  page := public.caliber_pull(first_owner,0,2);
  ASSERT jsonb_array_length(page->'changes') = 2 AND (page->>'hasMore')::boolean, 'bounded paging';
  merge := root || jsonb_build_object('operationID','0199b000-1000-7000-8000-000000000010',
    'baseRevision',root->>'operationID','logicalClock',4,
    'resolves',jsonb_build_array(left_branch->>'operationID',right_branch->>'operationID'));
  PERFORM public.caliber_push(first_owner,jsonb_build_array(merge));
  offline_child := root || jsonb_build_object('operationID','0199b000-1000-7000-8000-000000000011',
    'baseRevision',left_branch->>'operationID','logicalClock',5);
  PERFORM public.caliber_push(first_owner,jsonb_build_array(offline_child));
  historical_merge := merge || jsonb_build_object('operationID','0199b000-1000-7000-8000-000000000012','logicalClock',6);
  PERFORM public.caliber_push(first_owner,jsonb_build_array(historical_merge));
  ASSERT (SELECT count(*) FROM public.caliber_revisions r WHERE NOT EXISTS (
    SELECT 1 FROM public.caliber_revisions child WHERE
      child.envelope->>'baseRevision'=r.operation_id::text OR
      (child.envelope->'resolves') ? r.operation_id::text)) = 3, 'concurrent leaves must survive historical merge';
  before_count := (SELECT count(*) FROM public.caliber_revisions);
  denied := false;
  BEGIN
    PERFORM public.caliber_push(first_owner,jsonb_build_array(
      root || jsonb_build_object('operationID','0199b000-1000-7000-8000-000000000007','logicalClock',7),
      root || jsonb_build_object('operationID','0199b000-1000-7000-8000-000000000008',
        'baseRevision',root->>'operationID','logicalClock',0)));
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'invalid_parent' THEN RAISE; END IF;
    denied := true;
  END;
  ASSERT denied AND (SELECT count(*) FROM public.caliber_revisions)=before_count, 'whole invalid batch must roll back';
  denied := false;
  BEGIN
    PERFORM public.caliber_push(first_owner,jsonb_build_array(root || jsonb_build_object('tombstone',true)));
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'operation_collision' THEN RAISE; END IF;
    denied := true;
  END;
  ASSERT denied, 'changed retry must reject';
  PERFORM set_config('request.jwt.claim.sub',second_subject::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',second_subject,'role','authenticated')::text,true);
  ASSERT (SELECT count(*) FROM public.caliber_revisions)=0, 'cross-account table read';
  denied := false;
  BEGIN
    PERFORM public.caliber_push(first_owner,jsonb_build_array(root));
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'unauthorized' THEN RAISE; END IF;
    denied := true;
  END;
  ASSERT denied, 'cross-owner push';
  denied := false;
  BEGIN
    PERFORM public.caliber_pull(first_owner,0,100);
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'unauthorized' THEN RAISE; END IF;
    denied := true;
  END;
  ASSERT denied, 'cross-owner pull';
  PERFORM public.caliber_push(second_owner,jsonb_build_array(root || jsonb_build_object('ownerID',second_owner)));
  ASSERT (SELECT count(*) FROM public.caliber_revisions)=1, 'second owner own read';
  PERFORM set_config('request.jwt.claim.sub','',true);
  PERFORM set_config('request.jwt.claims','{}',true);
  denied := false;
  BEGIN
    PERFORM public.caliber_pull(second_owner,0,100);
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'unauthorized' THEN RAISE; END IF;
    denied := true;
  END;
  ASSERT denied, 'authenticated role without a subject';
  EXECUTE 'SET LOCAL ROLE anon';
  denied := false;
  BEGIN
    PERFORM public.caliber_pull(second_owner,0,100);
  EXCEPTION WHEN insufficient_privilege THEN denied := true;
  END;
  ASSERT denied, 'anonymous RPC execution';
  EXECUTE 'RESET ROLE';
END;
$fixture$;
ROLLBACK;
-- An assertion error stops execution before this final result.
SELECT
  NOT EXISTS (SELECT 1 FROM auth.users WHERE id IN
    ('c71dfb62-e139-4fca-afb6-8d29cda70261','fdc711c7-089d-4807-af2b-9b99ff72ef4a')) AS fixture_subjects_removed,
  NOT EXISTS (SELECT 1 FROM public.caliber_accounts WHERE owner_id IN
    ('0199b000-1000-7000-8000-000000000001','0199b000-1000-7000-8000-000000000009')) AS fixture_owners_removed,
  NOT EXISTS (SELECT 1 FROM public.caliber_revisions WHERE owner_id IN
    ('0199b000-1000-7000-8000-000000000001','0199b000-1000-7000-8000-000000000009')) AS fixture_revisions_removed;
