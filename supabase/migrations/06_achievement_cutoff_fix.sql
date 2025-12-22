-- Migration to update achievement RPCs to exclude current day (H-1 Cut-off)
-- Explicitly using (now() AT TIME ZONE 'Asia/Makassar')::date for reliable local date comparison

-- 1. Update Warehouse Achievement
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
  WITH cutoff_date AS (
    SELECT (now() AT TIME ZONE 'Asia/Makassar')::date as d
  ),
  loto_counts AS (
    SELECT
      ls.warehouse_code as w,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_records lr ON lr.session_id = ls.session_code
    WHERE ls.created_at >= (cd.d - days_back)
      AND ls.created_at < cd.d -- Exclude Today (WITA)
    GROUP BY 1
  ),
  verification_counts AS (
    SELECT
      lv.warehouse_code as w,
      count(*) as cnt
    FROM loto_verification lv
    JOIN cutoff_date cd ON true
    WHERE issued_date >= (cd.d - days_back)
      AND issued_date < cd.d -- Exclude Today (WITA)
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

-- 2. Update Fuelman Achievement (NRP)
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
  WITH cutoff_date AS (
    SELECT (now() AT TIME ZONE 'Asia/Makassar')::date as d
  ),
  fuelmen AS (
    SELECT m.nrp, m.nama
    FROM manpower m
    WHERE m.position::int = 5 AND m.active = true
  ),
  loto_counts AS (
    SELECT
      TRIM(ls.fuelman) as fuelman,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_records lr ON lr.session_id = ls.session_code
    WHERE ls.created_at >= (cd.d - days_back)
      AND ls.created_at < cd.d -- Exclude Today (WITA)
    GROUP BY 1
  ),
  verification_counts AS (
    SELECT
      TRIM(ls.fuelman) as fuelman,
      count(lv.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_verification lv ON lv.session_code = ls.session_code
    WHERE ls.created_at >= (cd.d - days_back)
      AND ls.created_at < cd.d -- Exclude Today (WITA)
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

-- 3. Update Trend
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
    WHERE ls.created_at >= (cd.d - days_back)
      AND ls.created_at < cd.d -- Exclude Today (WITA)
    GROUP BY 1, 2
  ),
  verification_counts AS (
    SELECT
      lv.issued_date as d,
      lv.shift as s,
      count(*) as cnt
    FROM loto_verification lv
    JOIN cutoff_date cd ON true
    WHERE lv.issued_date >= (cd.d - days_back)
      AND lv.issued_date < cd.d -- Exclude Today (WITA)
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
