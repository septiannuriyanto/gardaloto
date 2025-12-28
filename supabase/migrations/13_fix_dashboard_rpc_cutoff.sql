-- Migration to update dashboard cutoff logic to depend on the MAX date in loto_verification
-- Replaces logic 'Exclude Today' with 'Include up to MAX(issued_date)'
-- Uses session_code 'YYMMDD' prefix for accurate date grouping

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
    -- Cutoff is MAX issued_date + 1 day
    SELECT (COALESCE(MAX(issued_date), (now() AT TIME ZONE 'Asia/Makassar')::date) + 1)::date as d
    FROM loto_verification
  ),
  loto_counts AS (
    SELECT
      ls.warehouse_code as w,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_records lr ON lr.session_id = ls.session_code
    -- HYBRID DATE PARSING: Handle both 'YYYYMMDD' (started with 20...) and 'YYMMDD' formats
    WHERE (
      CASE 
        WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
        ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
      END
    ) >= (cd.d - days_back)
    AND (
      CASE 
        WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
        ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
      END
    ) < cd.d
    GROUP BY 1
  ),
  verification_counts AS (
    SELECT
      lv.warehouse_code as w,
      count(*) as cnt
    FROM loto_verification lv
    JOIN cutoff_date cd ON true
    WHERE issued_date >= (cd.d - days_back)
      AND issued_date < cd.d
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
    SELECT (COALESCE(MAX(issued_date), (now() AT TIME ZONE 'Asia/Makassar')::date) + 1)::date as d
    FROM loto_verification
  ),
  loto_counts AS (
    SELECT
      TRIM(ls.fuelman) as fuelman,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_records lr ON lr.session_id = ls.session_code
    -- Extract date from session_code (YYYYMMDD...)
    WHERE (
      CASE 
        WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
        ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
      END
    ) >= (cd.d - days_back)
      AND (
      CASE 
        WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
        ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
      END
    ) < cd.d
    GROUP BY 1
  ),
  verification_counts AS (
    SELECT
      TRIM(ls.fuelman) as fuelman,
      count(lv.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_verification lv ON lv.session_code = ls.session_code
    -- Use session_code date for consistency!
    WHERE (
      CASE 
        WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
        ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
      END
    ) >= (cd.d - days_back)
      AND (
      CASE 
        WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
        ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
      END
    ) < cd.d
    GROUP BY 1
  ),
  -- Identify all relevant NRPs (Position 5 OR anyone with activity)
  relevant_nrps AS (
    SELECT m.nrp
    FROM manpower m
    WHERE m.position::int = 5 AND m.active = true
    UNION
    SELECT fuelman FROM loto_counts
    UNION
    SELECT fuelman FROM verification_counts
  )
  SELECT
    m.nrp::text,
    m.nama::text as name,
    CASE WHEN COALESCE(vc.cnt, 0) > 0 THEN
      ROUND((COALESCE(lc.cnt, 0)::numeric / vc.cnt) * 100, 2)
    ELSE
      0
    END as percentage,
    COALESCE(lc.cnt, 0) as loto_count,
    COALESCE(vc.cnt, 0) as verification_count
  FROM relevant_nrps rn
  JOIN manpower m ON m.nrp = rn.nrp -- Get name from manpower
  LEFT JOIN loto_counts lc ON lc.fuelman = TRIM(m.nrp)
  LEFT JOIN verification_counts vc ON vc.fuelman = TRIM(m.nrp)
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
    SELECT (COALESCE(MAX(issued_date), (now() AT TIME ZONE 'Asia/Makassar')::date) + 1)::date as d
    FROM loto_verification
  ),
  loto_counts AS (
    SELECT
      -- Group by date extracted from session_code
      (
        CASE 
          WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
          ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
        END
      ) as d,
      ls.create_shift as s,
      count(lr.id) as cnt
    FROM loto_sessions ls
    JOIN cutoff_date cd ON true
    JOIN loto_records lr ON lr.session_id = ls.session_code
    WHERE (
        CASE 
          WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
          ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
        END
    ) >= (cd.d - days_back)
      AND (
        CASE 
          WHEN ls.session_code LIKE '20%' THEN to_date(substring(ls.session_code from 1 for 8), 'YYYYMMDD')
          ELSE to_date(substring(ls.session_code from 1 for 6), 'YYMMDD')
        END
    ) < cd.d
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
      AND lv.issued_date < cd.d
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
