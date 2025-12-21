-- RPC for LOTO Trend (Fix: Count Records instead of Sessions)
-- Item Compliance: (Total Loto Records / Total Verifications) * 100
CREATE OR REPLACE FUNCTION get_loto_achievement_trend(days_back int DEFAULT 30)
RETURNS TABLE (
  date date,
  shift smallint,
  total_loto bigint,
  total_verification bigint,
  percentage numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH loto_counts AS (
    SELECT
      date(ls.created_at) as d,
      ls.create_shift as s,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN loto_records lr ON lr.session_id = ls.session_code
    WHERE ls.created_at >= (current_date - days_back)
    GROUP BY 1, 2
  ),
  verification_counts AS (
    SELECT
      lv.issued_date as d,
      lv.shift as s,
      count(*) as cnt
    FROM loto_verification lv
    WHERE lv.issued_date >= (current_date - days_back)
    GROUP BY 1, 2
  )
  SELECT
    COALESCE(lc.d, vc.d) as date,
    COALESCE(lc.s, vc.s) as shift,
    COALESCE(lc.cnt, 0) as total_loto,
    COALESCE(vc.cnt, 0) as total_verification,
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
