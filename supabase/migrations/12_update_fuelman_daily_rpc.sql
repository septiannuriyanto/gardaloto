-- Migration to update get_fuelman_daily_achievement
-- Aligns logic with Dashboard:
-- 1. Use MAX(issued_date) from loto_verification as base (plus 1 day)
-- 2. Use session_code (YYMMDD) to determine date of sessions

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
    -- Align with Dashboard Cutoff
    SELECT (COALESCE(MAX(issued_date), (now() AT TIME ZONE 'Asia/Makassar')::date) + 1)::date as d
    FROM loto_verification
  ),
  loto_counts AS (
    SELECT
      to_date(substring(ls.session_code from 1 for 6), 'YYMMDD') as d,
      ls.create_shift as s,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_records lr ON lr.session_id = ls.session_code
    WHERE TRIM(ls.fuelman) = p_nrp
      AND to_date(substring(ls.session_code from 1 for 6), 'YYMMDD') >= (cd.d - days_back)
      AND to_date(substring(ls.session_code from 1 for 6), 'YYMMDD') < cd.d
    GROUP BY 1, 2
  ),
  verification_counts AS (
    SELECT
      to_date(substring(ls.session_code from 1 for 6), 'YYMMDD') as d,
      ls.create_shift as s,
      count(lv.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_verification lv ON lv.session_code = ls.session_code
    WHERE TRIM(ls.fuelman) = p_nrp
      AND to_date(substring(ls.session_code from 1 for 6), 'YYMMDD') >= (cd.d - days_back)
      AND to_date(substring(ls.session_code from 1 for 6), 'YYMMDD') < cd.d
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
