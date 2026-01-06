-- 16. Fuelman Monthly Records RPC
-- Returns detailed records for a fuelman within the dynamic monthly cutoff period.

CREATE OR REPLACE FUNCTION get_fuelman_monthly_records(nrp_input text)
RETURNS TABLE (
  timestamp_taken timestamp with time zone,
  code_number text,
  session_id text,
  create_shift smallint
)
LANGUAGE plpgsql
AS $$
DECLARE
  max_date date;
  start_date date;
  cutoff_next_day date;
BEGIN
  -- 1. Determine MAX Date from loto_verification session_code (YYMMDD...)
  -- Same logic as get_loto_ranking_nrp
  SELECT MAX(to_date(substring(session_code from 1 for 6), 'YYMMDD'))
  INTO max_date
  FROM loto_verification
  WHERE session_code ~ '^\d{6}';

  IF max_date IS NULL THEN
    max_date := (now() AT TIME ZONE 'Asia/Makassar')::date;
  END IF;

  -- 2. Define Range
  start_date := date_trunc('month', max_date)::date;
  cutoff_next_day := (max_date + interval '1 day')::date;

  -- 3. Return Records
  RETURN QUERY
  SELECT
    lr.timestamp_taken,
    lr.code_number,
    lr.session_id,
    ls.create_shift
  FROM loto_records lr
  JOIN loto_sessions ls ON lr.session_id = ls.session_code
  WHERE
    ls.fuelman = nrp_input
    AND to_date(substring(lr.session_id from 1 for 6), 'YYMMDD') >= start_date
    AND to_date(substring(lr.session_id from 1 for 6), 'YYMMDD') < cutoff_next_day
  ORDER BY lr.timestamp_taken DESC;
END;
$$;
