-- Create RPC function to calculate LOTO achievement trend
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
      date(created_at) as d,
      create_shift as s,
      count(*) as cnt
    FROM loto_sessions
    WHERE created_at >= (current_date - days_back)
    GROUP BY 1, 2
  ),
  verification_counts AS (
    SELECT
      issued_date as d,
      shift as s,
      count(*) as cnt
    FROM loto_verification
    WHERE issued_date >= (current_date - days_back)
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
