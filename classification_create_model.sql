# Confusion matrix at default 0.5 threshold (fixed CTE chaining)
cm_default_sql = f"""
{CANONICAL_BASE_SQL}
{SPLIT_CLAUSE}
, eval_rows AS (
  SELECT
    diverted AS label,
    dep_delay, distance, carrier, origin, dest, day_of_week
  FROM split_cte
  WHERE split_flag = 'EVAL'
)
SELECT
  SUM(CASE WHEN label = TRUE  AND predicted_diverted = TRUE  THEN 1 ELSE 0 END) AS TP,
  SUM(CASE WHEN label = FALSE AND predicted_diverted = TRUE  THEN 1 ELSE 0 END) AS FP,
  SUM(CASE WHEN label = TRUE  AND predicted_diverted = FALSE THEN 1 ELSE 0 END) AS FN,
  SUM(CASE WHEN label = FALSE AND predicted_diverted = FALSE THEN 1 ELSE 0 END) AS TN
FROM ML.PREDICT(
  MODEL `{MODEL_BASE}`,
  (SELECT * FROM eval_rows)
)
"""
bq.query(cm_default_sql, location="US").to_dataframe()


CUSTOM_THRESHOLD = 0.25 

cm_thresh_sql = f"""
{CANONICAL_BASE_SQL}
{SPLIT_CLAUSE}
, eval_rows AS (
  SELECT
    diverted AS label,
    dep_delay, distance, carrier, origin, dest, day_of_week
  FROM split_cte
  WHERE split_flag = 'EVAL'
)
, scored AS (
  SELECT
    label,
    -- Get probability for label=TRUE by name, not OFFSET
    (
      SELECT prob
      FROM UNNEST(predicted_diverted_probs)
      WHERE label = TRUE
    ) AS p_true,
    CAST((
      SELECT prob
      FROM UNNEST(predicted_diverted_probs)
      WHERE label = TRUE
    ) >= {CUSTOM_THRESHOLD} AS BOOL) AS pred_label
  FROM ML.PREDICT(
    MODEL `{MODEL_BASE}`,
    (SELECT * FROM eval_rows)
  )
)
SELECT
  SUM(CASE WHEN label = TRUE  AND pred_label = TRUE  THEN 1 ELSE 0 END) AS TP,
  SUM(CASE WHEN label = FALSE AND pred_label = TRUE  THEN 1 ELSE 0 END) AS FP,
  SUM(CASE WHEN label = TRUE  AND pred_label = FALSE THEN 1 ELSE 0 END) AS FN,
  SUM(CASE WHEN label = FALSE AND pred_label = FALSE THEN 1 ELSE 0 END) AS TN
FROM scored
"""
bq.query(cm_thresh_sql, location="US").to_dataframe()
