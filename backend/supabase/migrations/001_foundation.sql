-- Foundation sync journal, not a port of the app's private SQLite schema.
-- Domain adapters consume validated operations; direct arbitrary table writes are never exposed.
CREATE TABLE public.caliber_accounts (
  owner_id uuid PRIMARY KEY,
  subject uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.caliber_revisions (
  cursor bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY CHECK(cursor BETWEEN 1 AND 9007199254740991),
  owner_id uuid NOT NULL REFERENCES public.caliber_accounts(owner_id) ON DELETE CASCADE,
  subject uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  operation_id uuid NOT NULL,
  entity_id uuid NOT NULL,
  namespace text NOT NULL CHECK (namespace IN ('note','weight','food','set')),
  envelope jsonb NOT NULL CHECK (jsonb_typeof(envelope)='object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(subject,operation_id)
);
CREATE INDEX caliber_pull ON public.caliber_revisions(subject,owner_id,cursor);
ALTER TABLE public.caliber_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caliber_revisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY caliber_accounts_owner ON public.caliber_accounts FOR SELECT TO authenticated USING(subject=auth.uid());
CREATE POLICY caliber_revisions_owner ON public.caliber_revisions FOR SELECT TO authenticated USING(subject=auth.uid());
REVOKE ALL ON public.caliber_accounts,public.caliber_revisions FROM anon,authenticated;
GRANT SELECT ON public.caliber_accounts,public.caliber_revisions TO authenticated;

-- All writes flow through one serialized, authenticated, idempotent command transaction.
CREATE FUNCTION public.caliber_push(p_owner uuid,p_operations jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  who uuid := auth.uid(); item jsonb; prior jsonb; parent jsonb; result jsonb := '[]'::jsonb;
  revision_cursor bigint; op uuid; entity uuid; kind text; parent_id uuid; parent_clock bigint;
  v7 text := '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
  payload_json jsonb; resolves jsonb; ancestor_ids uuid[];
BEGIN
  IF who IS NULL THEN RAISE EXCEPTION 'unauthorized'; END IF;
  IF p_owner IS NULL OR p_owner::text !~ v7 OR jsonb_typeof(p_operations) IS DISTINCT FROM 'array'
      OR jsonb_array_length(p_operations) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_request'; END IF;
  INSERT INTO public.caliber_accounts(owner_id,subject) VALUES(p_owner,who) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM public.caliber_accounts WHERE owner_id=p_owner AND subject=who FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauthorized'; END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(p_operations) LOOP
    IF jsonb_typeof(item) IS DISTINCT FROM 'object' OR item->>'ownerID' IS DISTINCT FROM p_owner::text
      OR coalesce(item->>'operationID','') !~ v7 OR coalesce(item->>'entityID','') !~ v7
      OR coalesce(item->>'deviceID','') !~ v7 OR coalesce(item->>'namespace','') NOT IN ('note','weight','food','set')
      OR jsonb_typeof(item->'tombstone') IS DISTINCT FROM 'boolean'
      OR jsonb_typeof(item->'logicalClock') IS DISTINCT FROM 'number'
      OR (item->>'logicalClock') !~ '^[0-9]+$' OR (item->>'logicalClock')::numeric > 9007199254740991
      OR jsonb_typeof(item->'payload') IS DISTINCT FROM 'string'
      OR jsonb_typeof(item->'resolves') IS DISTINCT FROM 'array'
      OR (item ? 'baseRevision' AND jsonb_typeof(item->'baseRevision') NOT IN ('string','null')) THEN RAISE EXCEPTION 'invalid_operation'; END IF;
    IF EXISTS(SELECT 1 FROM jsonb_object_keys(item) k WHERE k NOT IN ('operationID','ownerID','entityID','namespace','baseRevision','deviceID','logicalClock','tombstone','payload','resolves')) THEN RAISE EXCEPTION 'invalid_operation'; END IF;
    payload_json := convert_from(decode(item->>'payload','base64'),'UTF8')::jsonb;
    IF octet_length(decode(item->>'payload','base64')) > 65536 OR jsonb_typeof(payload_json) <> 'object' THEN RAISE EXCEPTION 'invalid_payload'; END IF;
    op := (item->>'operationID')::uuid; entity := (item->>'entityID')::uuid; kind := item->>'namespace';
    SELECT envelope,cursor INTO prior,revision_cursor FROM public.caliber_revisions WHERE subject=who AND operation_id=op;
    IF FOUND THEN
      IF prior <> item THEN RAISE EXCEPTION 'operation_collision'; END IF;
      result := result || jsonb_build_array(jsonb_build_object('operationID',op::text,'cursor',revision_cursor));
      CONTINUE;
    END IF;
    FOR parent IN SELECT value FROM jsonb_array_elements((CASE WHEN item->>'baseRevision' IS NULL THEN '[]'::jsonb ELSE jsonb_build_array(item->>'baseRevision') END) || (item->'resolves')) LOOP
      IF jsonb_typeof(parent) <> 'string' OR (parent#>>'{}') !~ v7 THEN RAISE EXCEPTION 'invalid_parent'; END IF;
      parent_id := (parent#>>'{}')::uuid;
      SELECT (envelope->>'logicalClock')::bigint INTO parent_clock FROM public.caliber_revisions
        WHERE subject=who AND owner_id=p_owner AND entity_id=entity AND namespace=kind AND operation_id=parent_id;
      IF NOT FOUND OR parent_clock >= (item->>'logicalClock')::bigint THEN RAISE EXCEPTION 'invalid_parent'; END IF;
    END LOOP;
    IF jsonb_array_length(item->'resolves') > 0 THEN
      resolves := item->'resolves';
      IF jsonb_array_length(resolves) < 2 OR
        (SELECT count(DISTINCT value) FROM jsonb_array_elements_text(resolves)) <> jsonb_array_length(resolves)
        THEN RAISE EXCEPTION 'invalid_resolution_count'; END IF;
      -- An offline resolution may reach the server after a newer child of one resolved branch.
      -- Keep both leaves. Requiring today's server leaves would permanently block that outbox.
      -- A valid resolution joins an antichain, with an optional base common to all branches.
      FOR parent IN SELECT value FROM jsonb_array_elements(resolves) LOOP
        parent_id := (parent#>>'{}')::uuid;
        WITH RECURSIVE ancestors(id) AS (
          SELECT edge.value::uuid FROM public.caliber_revisions r
          CROSS JOIN LATERAL jsonb_array_elements_text(
            (CASE WHEN r.envelope->>'baseRevision' IS NULL THEN '[]'::jsonb ELSE jsonb_build_array(r.envelope->>'baseRevision') END)
            || (r.envelope->'resolves')) edge
          WHERE r.subject=who AND r.owner_id=p_owner AND r.entity_id=entity AND r.namespace=kind AND r.operation_id=parent_id
          UNION
          SELECT edge.value::uuid FROM ancestors a JOIN public.caliber_revisions r ON r.operation_id=a.id
          CROSS JOIN LATERAL jsonb_array_elements_text(
            (CASE WHEN r.envelope->>'baseRevision' IS NULL THEN '[]'::jsonb ELSE jsonb_build_array(r.envelope->>'baseRevision') END)
            || (r.envelope->'resolves')) edge
          WHERE r.subject=who AND r.owner_id=p_owner AND r.entity_id=entity AND r.namespace=kind
        ) SELECT coalesce(array_agg(id),ARRAY[]::uuid[]) INTO ancestor_ids FROM ancestors;
        IF EXISTS(SELECT 1 FROM jsonb_array_elements_text(resolves) r WHERE r.value::uuid=ANY(ancestor_ids)) THEN RAISE EXCEPTION 'invalid_resolution_related'; END IF;
        IF item->>'baseRevision' IS NOT NULL AND NOT (item->>'baseRevision')::uuid=ANY(ancestor_ids) THEN RAISE EXCEPTION 'invalid_resolution_base'; END IF;
      END LOOP;
    END IF;
    INSERT INTO public.caliber_revisions(owner_id,subject,operation_id,entity_id,namespace,envelope)
      VALUES(p_owner,who,op,entity,kind,item) RETURNING cursor INTO revision_cursor;
    result := result || jsonb_build_array(jsonb_build_object('operationID',op::text,'cursor',revision_cursor));
  END LOOP;
  RETURN result;
END;
$$;

CREATE FUNCTION public.caliber_pull(p_owner uuid,p_after bigint,p_limit integer DEFAULT 100) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE who uuid:=auth.uid(); changes jsonb; last_cursor bigint; more boolean;
BEGIN
  IF who IS NULL THEN RAISE EXCEPTION 'unauthorized'; END IF;
  IF p_owner IS NULL OR p_after IS NULL OR p_after NOT BETWEEN 0 AND 9007199254740991 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_cursor'; END IF;
  IF EXISTS(SELECT 1 FROM public.caliber_accounts WHERE owner_id=p_owner AND subject<>who) THEN RAISE EXCEPTION 'unauthorized'; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('cursor',cursor,'operation',envelope) ORDER BY cursor),'[]'::jsonb),coalesce(max(cursor),p_after)
    INTO changes,last_cursor FROM (SELECT cursor,envelope FROM public.caliber_revisions
    WHERE subject=who AND owner_id=p_owner AND cursor>p_after ORDER BY cursor LIMIT p_limit) page;
  SELECT EXISTS(SELECT 1 FROM public.caliber_revisions WHERE subject=who AND owner_id=p_owner AND cursor>last_cursor) INTO more;
  RETURN jsonb_build_object('ownerID',p_owner::text,'cursor',last_cursor,'changes',changes,'hasMore',more);
END;
$$;
REVOKE ALL ON FUNCTION public.caliber_push(uuid,jsonb),public.caliber_pull(uuid,bigint,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.caliber_push(uuid,jsonb),public.caliber_pull(uuid,bigint,integer) TO authenticated;
