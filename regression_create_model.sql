MODEL_DATASET = f"{PROJECT_ID}.unit2_flights"
bq.query(f"CREATE SCHEMA IF NOT EXISTS `{MODEL_DATASET}`", location=REGION).result()

# unique name per run without deprecated utcnow()
MODEL_BASE = f"{MODEL_DATASET}.clf_diverted_base_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}"

sql_create_model = f"""
CREATE MODEL `{MODEL_BASE}`
OPTIONS (MODEL_TYPE='LOGISTIC_REG', INPUT_LABEL_COLS=['diverted']) AS
{CANONICAL_BASE_SQL}
{SPLIT_CLAUSE}
SELECT
  diverted,
  dep_delay, distance, carrier, origin, dest, day_of_week
FROM split_cte
WHERE split_flag = 'TRAIN'
"""
bq.query(sql_create_model, location=REGION).result()
print("✅ Baseline model trained:", MODEL_BASE)

sql_eval = f"""
SELECT * FROM ML.EVALUATE(
  MODEL `{MODEL_BASE}`,
  (
    {CANONICAL_BASE_SQL}
    {SPLIT_CLAUSE}
    SELECT
      diverted,
      dep_delay, distance, carrier, origin, dest, day_of_week
    FROM split_cte
    WHERE split_flag = 'EVAL'
  )
)
"""
eval_df = bq.query(sql_eval, location=REGION).to_dataframe()
eval_df


CREATE OR REPLACE MODEL `{MODEL_XFORM}`
TRANSFORM (
  -- label: must be present by name (no CAST/alias)
  diverted,

  -- engineered features
  CONCAT(origin, '-', dest) AS route,
  EXTRACT(DAYOFWEEK FROM flight_date) AS day_of_week,
  CASE
    WHEN dep_delay < -5  THEN 'early'
    WHEN dep_delay <=  5 THEN 'on_time'
    WHEN dep_delay <= 15 THEN 'minor'
    WHEN dep_delay <= 45 THEN 'moderate'
    ELSE 'major'
  END AS dep_delay_bucket,

  -- pass-through raw features
  dep_delay, distance, carrier, origin, dest
)
OPTIONS (MODEL_TYPE='LOGISTIC_REG', INPUT_LABEL_COLS=['diverted']) AS
{CANONICAL_BASE_SQL}
{SPLIT_CLAUSE}
SELECT *
FROM split_cte
WHERE split_flag = 'TRAIN'
"""
bq.query(sql_xform_create, location="US").result()
print("✅ Engineered model trained:", MODEL_XFORM)

