-- Fix type mismatch for verification_time in get_fuelman_reconciliation RPC
-- Explicitly cast date to timestamp with time zone

CREATE OR REPLACE FUNCTION get_fuelman_reconciliation(
  p_nrp text,
  p_date date,
  p_shift int
)
RETURNS TABLE (
  unit_code text,
  status text, 
  loto_time timestamp with time zone,
  verification_time timestamp with time zone
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
      lv.issued_date as t
    FROM loto_verification lv
    JOIN target_sessions ts ON lv.session_code = ts.session_code
  ),
  records AS (
    SELECT 
      lr.code_number as u, 
      lr.timestamp_taken as t
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
    r.t, -- loto_time (timestamptz)
    v.t::timestamp with time zone -- verification_time (EXPLICIT CAST)
  FROM verifications v
  FULL OUTER JOIN records r ON v.u = r.u
  ORDER BY status, unit_code;
END;
$$;
