-- 15. Update Fuelman Ranking with Dynamic Cutoff (Max Session Code)
-- Logic:
-- 1. max_date = MAX(parsed date from loto_verification.session_code)
-- 2. start_date = Start of Month of max_date
-- 3. Filter Plan and Actual using this range.

CREATE OR REPLACE FUNCTION get_loto_ranking_nrp(days_back int DEFAULT 30)
RETURNS TABLE (
  nrp text,
  name text,
  percentage numeric,
  loto_count bigint,
  verification_count bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
  max_date date;
  start_date date;
  cutoff_next_day date;
BEGIN
  -- 1. Determine MAX Date from loto_verification session_code (YYMMDD...)
  SELECT MAX(to_date(substring(session_code from 1 for 6), 'YYMMDD'))
  INTO max_date
  FROM loto_verification
  WHERE session_code ~ '^\d{6}'; -- Basic check to ensure it starts with digits

  -- Fallback if no data
  IF max_date IS NULL THEN
    max_date := (now() AT TIME ZONE 'Asia/Makassar')::date;
  END IF;

  -- 2. Define Range
  -- Start: 1st day of the month of max_date
  start_date := date_trunc('month', max_date)::date;
  
  -- End: max_date + 1 day (for exclusive upper bound <)
  cutoff_next_day := (max_date + interval '1 day')::date;

  RETURN QUERY
  WITH 
  -- PLAN: loto_verification
  plan_data AS (
    SELECT
      ls.fuelman,
      COUNT(lv.id) as cnt
    FROM loto_verification lv
    JOIN loto_sessions ls ON lv.session_code = ls.session_code
    WHERE 
      -- Filter by parsing session_code for consistency with the cutoff logic
      to_date(substring(lv.session_code from 1 for 6), 'YYMMDD') >= start_date
      AND to_date(substring(lv.session_code from 1 for 6), 'YYMMDD') < cutoff_next_day
    GROUP BY ls.fuelman
  ),
  -- ACTUAL: loto_records
  actual_data AS (
    SELECT
      ls.fuelman,
      COUNT(lr.id) as cnt
    FROM loto_records lr
    JOIN loto_sessions ls ON lr.session_id = ls.session_code
    WHERE 
       -- Filter by parsing session_id (which is session_code)
      to_date(substring(lr.session_id from 1 for 6), 'YYMMDD') >= start_date
      AND to_date(substring(lr.session_id from 1 for 6), 'YYMMDD') < cutoff_next_day
    GROUP BY ls.fuelman
  ),
  relevant_nrps AS (
    SELECT p.fuelman as nrp FROM plan_data p
    UNION
    SELECT a.fuelman as nrp FROM actual_data a
    UNION
    SELECT m.nrp FROM manpower m WHERE m.position::int = 5 AND m.active = true
  )
  SELECT
    rn.nrp::text,
    COALESCE(m.nama, rn.nrp)::text as name,
    CASE WHEN COALESCE(p.cnt, 0) > 0 THEN
      ROUND((COALESCE(a.cnt, 0)::numeric / p.cnt) * 100, 2)
    ELSE
      0
    END as percentage,
    COALESCE(a.cnt, 0) as loto_count,
    COALESCE(p.cnt, 0) as verification_count
  FROM relevant_nrps rn
  LEFT JOIN manpower m ON m.nrp = rn.nrp
  LEFT JOIN plan_data p ON p.fuelman = rn.nrp
  LEFT JOIN actual_data a ON a.fuelman = rn.nrp
  ORDER BY 3 DESC, 2 ASC;
END;
$$;
