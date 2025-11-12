# 2) Compare baseline vs engineered on identical EVAL slice
compare_sql = f"""
-- Baseline metrics (use canonical day_of_week column)
SELECT 'baseline' AS model_version, * FROM ML.EVALUATE(
  MODEL `{MODEL_BASE}`,
  (
    {CANONICAL_BASE_SQL}
    {SPLIT_CLAUSE}
    SELECT
      diverted,
      dep_delay, distance, carrier, origin, dest, day_of_week, flight_date
    FROM split_cte
    WHERE split_flag = 'EVAL'
  )
)
UNION ALL
-- Engineered metrics: provide the raw columns referenced by TRANSFORM
SELECT 'engineered' AS model_version, * FROM ML.EVALUATE(
  MODEL `{MODEL_XFORM}`,
  (
    {CANONICAL_BASE_SQL}
    {SPLIT_CLAUSE}
    SELECT
      diverted,                               -- label
      dep_delay, distance, carrier, origin, dest,
      flight_date                             -- used to make day_of_week
    FROM split_cte
    WHERE split_flag = 'EVAL'
  )
)
"""