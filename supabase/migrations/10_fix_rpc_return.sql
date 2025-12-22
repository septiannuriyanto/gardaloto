-- Force update of get_fuelman_reconciliation to ensure record_id is returned
-- This fixes the issue where "Sync" fails due to missing ID
-- Also fixes "ambiguous column" error by using table aliases
CREATE OR REPLACE FUNCTION get_fuelman_reconciliation(
  p_nrp text,
  p_date date,
  p_shift int
)
RETURNS TABLE (
  unit_code text,
  status text, 
  loto_time timestamp with time zone,
  verification_time timestamp with time zone,
  record_id uuid, -- Required for Sync
  session_code text -- Required for image upload
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH target_sessions AS (
    SELECT ls.session_code
    FROM loto_sessions ls
    WHERE TRIM(ls.fuelman) = p_nrp
      AND date(ls.created_at) = p_date
      AND ls.create_shift = p_shift
  ),
  verifications AS (
    SELECT 
      lv.unit_number as u, 
      lv.issued_date as t,
      ts.session_code as sc
    FROM loto_verification lv
    JOIN target_sessions ts ON lv.session_code = ts.session_code
  ),
  records AS (
    SELECT 
      lr.id as rid, -- We capture the ID here
      lr.code_number as u, 
      lr.timestamp_taken as t,
      lr.session_id as sc
    FROM loto_records lr
    JOIN target_sessions ts ON lr.session_id = ts.session_code
  )
  SELECT
    COALESCE(v.u, r.u)::text as unit_code,
    CASE 
      WHEN v.u IS NOT NULL AND r.u IS NOT NULL THEN 'MATCH'
      WHEN v.u IS NOT NULL AND r.u IS NULL THEN 'MISSING_LOTO'
      WHEN v.u IS NULL AND r.u IS NOT NULL THEN 'EXTRA_LOTO'
    END as status,
    v.t::timestamp with time zone as loto_time, -- Using alias for clarity
    r.t::timestamp with time zone as verification_time, -- Using alias for clarity
    r.rid as record_id, -- Explicitly returning as record_id
    COALESCE(v.sc, r.sc) as session_code
  FROM verifications v
  FULL OUTER JOIN records r ON v.u = r.u
  ORDER BY status, unit_code;
END;
$$;

-- 2. Function to update LOTO record unit code
-- This is required for the "Sync" action to work
CREATE OR REPLACE FUNCTION update_loto_record_unit(
  p_record_id uuid,
  p_new_unit_code text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE loto_records
  SET code_number = p_new_unit_code
  WHERE id = p_record_id;
END;
$$;
