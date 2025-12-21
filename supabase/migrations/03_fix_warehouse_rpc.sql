-- RPC for Warehouse Achievement (Fix: Count Records instead of Sessions)
-- Item Compliance: (Total Loto Records / Total Verifications) * 100
CREATE OR REPLACE FUNCTION get_loto_achievement_warehouse(days_back int DEFAULT 30)
RETURNS TABLE (
  warehouse_code text,
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
      ls.warehouse_code as w,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN loto_records lr ON lr.session_id = ls.session_code
    WHERE ls.created_at >= (current_date - days_back)
    GROUP BY 1
  ),
  verification_counts AS (
    SELECT
      lv.warehouse_code as w,
      count(*) as cnt
    FROM loto_verification lv
    WHERE issued_date >= (current_date - days_back)
    GROUP BY 1
  )
  SELECT
    COALESCE(lc.w, vc.w, 'Unknown') as warehouse_code,
    COALESCE(lc.cnt, 0) as total_loto,
    COALESCE(vc.cnt, 0) as total_verification,
    CASE WHEN COALESCE(vc.cnt, 0) > 0 THEN
      ROUND((COALESCE(lc.cnt, 0)::numeric / vc.cnt) * 100, 2)
    ELSE
      0
    END as percentage
  FROM loto_counts lc
  FULL OUTER JOIN verification_counts vc ON lc.w = vc.w
  ORDER BY 4 DESC, 1;
END;
$$;
