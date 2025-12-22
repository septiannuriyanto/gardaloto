-- Create a function to get the maximum session code from loto_verification
-- Returns the full session code as BIGINT to allow parsing date and shift
-- Format: YYMMDDSSSS
CREATE OR REPLACE FUNCTION public.get_max_session_code()
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
  SELECT
    MAX(
      CASE 
        WHEN LENGTH(session_code) > 4 THEN LEFT(session_code, LENGTH(session_code) - 4)::BIGINT
        ELSE NULL
      END
    )
  FROM public.loto_verification
  WHERE session_code IS NOT NULL
    AND session_code ~ '^[0-9]+.{4}$'; -- Starts with digits, ends with 4 chars
$$;
