-- RPC for NRP Ranking (Fuelman Achievement %)
-- Goal: Calculate Loto Records / Verifications for Active Fuelmen (Position 5)
-- FIX: Join on session_code (text) instead of id (bigint) if session_id in records is text.
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
BEGIN
  RETURN QUERY
  WITH fuelmen AS (
    SELECT m.nrp, m.nama
    FROM manpower m
    WHERE m.position::int = 5 AND m.active = true
  ),
  loto_counts AS (
    SELECT
      TRIM(ls.fuelman) as fuelman,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN loto_records lr ON lr.session_id = ls.session_code -- JOIN on session_code (text)
    WHERE ls.created_at >= (current_date - days_back)
    GROUP BY 1
  ),
  verification_counts AS (
    SELECT
      TRIM(ls.fuelman) as fuelman,
      count(lv.id) as cnt
    FROM loto_sessions ls
    JOIN loto_verification lv ON lv.session_id = ls.session_code -- JOIN on session_code (text)
    WHERE ls.created_at >= (current_date - days_back)
    GROUP BY 1
  )
  SELECT
    f.nrp::text,
    f.nama::text as name,
    CASE WHEN COALESCE(vc.cnt, 0) > 0 THEN
      ROUND((COALESCE(lc.cnt, 0)::numeric / vc.cnt) * 100, 2)
    ELSE
      0
    END as percentage,
    COALESCE(lc.cnt, 0) as loto_count,
    COALESCE(vc.cnt, 0) as verification_count
  FROM fuelmen f
  LEFT JOIN loto_counts lc ON lc.fuelman = TRIM(f.nrp)
  LEFT JOIN verification_counts vc ON vc.fuelman = TRIM(f.nrp)
  ORDER BY 3 DESC, 2;
END;
$$;
