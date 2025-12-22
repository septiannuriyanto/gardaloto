-- 1. Update get_fuelman_reconciliation to return record_id and session_code
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
  record_id uuid, -- NEW: To identify the LOTO record for syncing
  session_code text -- NEW: To identify the session for adding images
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH target_sessions AS (
    SELECT session_code
    FROM loto_sessions
    WHERE TRIM(fuelman) = p_nrp
      AND date(created_at) = p_date
      AND create_shift = p_shift
  ),
  verifications AS (
    SELECT 
      lv.unit_number as u, 
      lv.issued_date as t,
      ts.session_code as sc -- verification is linked to session
    FROM loto_verification lv
    JOIN target_sessions ts ON lv.session_code = ts.session_code
  ),
  records AS (
    SELECT 
      lr.id as rid, -- Record ID
      lr.code_number as u, 
      lr.timestamp_taken as t,
      lr.session_id as sc -- Record is linked to session
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
    r.t,
    v.t::timestamp with time zone,
    r.rid,
    COALESCE(v.sc, r.sc) as session_code
  FROM verifications v
  FULL OUTER JOIN records r ON v.u = r.u
  ORDER BY status, unit_code;
END;
$$;

-- 2. New RPC to update LOTO record unit code
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
