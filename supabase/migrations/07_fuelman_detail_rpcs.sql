-- RPCs for Fuelman Detail and Reconciliation
-- FIXED: Return type mismatch for verification_time (Date vs Timestamptz)

-- 1. Get Daily Achievement Trend for a Specific Fuelman
CREATE OR REPLACE FUNCTION get_fuelman_daily_achievement(p_nrp text, days_back int DEFAULT 30)
RETURNS TABLE (
  date date,
  shift smallint,
  loto_count bigint,
  verification_count bigint,
  percentage numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH cutoff_date AS (
    SELECT (now() AT TIME ZONE 'Asia/Makassar')::date as d
  ),
  loto_counts AS (
    SELECT
      date(ls.created_at) as d,
      ls.create_shift as s,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_records lr ON lr.session_id = ls.session_code
    WHERE TRIM(ls.fuelman) = p_nrp
      AND ls.created_at >= (cd.d - days_back)
      AND ls.created_at < cd.d
    GROUP BY 1, 2
  ),
  verification_counts AS (
    SELECT
      date(ls.created_at) as d,
      ls.create_shift as s,
      count(lv.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_verification lv ON lv.session_code = ls.session_code
    WHERE TRIM(ls.fuelman) = p_nrp
      AND ls.created_at >= (cd.d - days_back)
      AND ls.created_at < cd.d
    GROUP BY 1, 2
  )
  SELECT
    COALESCE(lc.d, vc.d) as date,
    COALESCE(lc.s, vc.s) as shift,
    COALESCE(lc.cnt, 0) as loto_count,
    COALESCE(vc.cnt, 0) as verification_count,
    CASE WHEN COALESCE(vc.cnt, 0) > 0 THEN
      ROUND((COALESCE(lc.cnt, 0)::numeric / vc.cnt) * 100, 2)
    ELSE
      0
    END as percentage
  FROM loto_counts lc
  FULL OUTER JOIN verification_counts vc ON lc.d = vc.d AND lc.s = vc.s
  ORDER BY 1 DESC, 2;
END;
$$;

-- 2. Get Reconciliation List
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
    r.t,
    v.t::timestamp with time zone -- CAST Date to Timestamptz
  FROM verifications v
  FULL OUTER JOIN records r ON v.u = r.u
  ORDER BY status, unit_code;
END;
$$;
