-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-telemetry alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_TELEMETRY.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic solar plant O&M knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.PLANT_SOP_DOCS AS
WITH causes AS (
  SELECT DISTINCT r.ROOT_CAUSE, h.CATEGORY
  FROM RAW.PLANT_DAILY r JOIN RAW.PLANTS h ON h.ID = r.ENTITY_ID
  WHERE r.ROOT_CAUSE IS NOT NULL AND r.LOSS_EVENT_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, ROOT_CAUSE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  ROOT_CAUSE,
  CATEGORY || ' - ' || ROOT_CAUSE || ' generation loss response' AS TITLE,
  'Synthetic demo SOP. Plant type: ' || CATEGORY || '. Generation loss cause: ' || ROOT_CAUSE || '. '
  || 'Step 1: notify the plant O&M shift technician, log the inverter and string IDs affected, compare the SCADA readings with a handheld clamp meter and thermal camera check, and isolate any string that shows a fault. '
  || 'Step 2: ' || CASE
       WHEN ROOT_CAUSE ILIKE '%overtemperature%' OR ROOT_CAUSE ILIKE '%fan%' THEN 'clear the inverter air intakes, swap the cooling fan from the spare-parts pool if it has stopped, and hold the inverter at its derated set point until heatsink temperature recovers.'
       WHEN ROOT_CAUSE ILIKE '%soiling%' THEN 'schedule an out-of-cycle module wash for the affected blocks, record the soiling ratio before and after cleaning and move the block forward in the cleaning rota.'
       WHEN ROOT_CAUSE ILIKE '%fuse%' OR ROOT_CAUSE ILIKE '%cable%' THEN 'lock out the combiner box, run an insulation resistance test on the affected strings, replace the failed fuse or cable section and re-energise one string at a time.'
       WHEN ROOT_CAUSE ILIKE '%tracker%' OR ROOT_CAUSE ILIKE '%stow%' THEN 'check the tracker row controller and drive motor, return stowed rows to tracking once wind speed is back under the stow limit, and log the rows that did not respond.'
       WHEN ROOT_CAUSE ILIKE '%curtailment%' OR ROOT_CAUSE ILIKE '%outage%' THEN 'record the grid operator instruction or outage start time, confirm the plant controller follows the dispatch set point and restart inverters in blocks once the grid is available.'
       WHEN ROOT_CAUSE ILIKE '%shading%' THEN 'walk the affected roof area, record the new obstruction and its shading window, and raise a change request with the building owner.'
       WHEN ROOT_CAUSE ILIKE '%battery%' OR ROOT_CAUSE ILIKE '%sensor%' THEN 'check the power conversion system or irradiance sensor against its reference, recalibrate or swap the unit from spares and flag readings since the last good calibration for review.'
       ELSE 'record the issue, isolate the affected strings and escalate to the regional O&M lead.'
     END
  || ' Step 3: if peak inverter temperature stays above 70 C or inverter load stays above 95% after recovery, keep the plant on the watch list and defer non-urgent outages. '
  || 'Step 4: confirm recovery of the in-range rate and record the root cause and inverter IDs in the O&M log.' AS CONTENT
FROM causes;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.PLANT_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, ROOT_CAUSE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, ROOT_CAUSE, CONTENT FROM SEARCH.PLANT_SOP_DOCS);

-- ---------- Peak inverter temperature anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.INVERTER_TEMP_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, INVERTER_TEMP_C::FLOAT AS INVERTER_TEMP
FROM RAW.PLANT_DAILY;
CREATE OR REPLACE VIEW ML.INVERTER_TEMP_TRAIN AS
SELECT * FROM ML.INVERTER_TEMP_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.INVERTER_TEMP_SERIES);
CREATE OR REPLACE VIEW ML.INVERTER_TEMP_DETECT AS
SELECT * FROM ML.INVERTER_TEMP_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.INVERTER_TEMP_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.INVERTER_TEMP_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.INVERTER_TEMP_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'INVERTER_TEMP',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.INVERTER_TEMP_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS INVERTER_TEMP, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.INVERTER_TEMP_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.INVERTER_TEMP_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'INVERTER_TEMP'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.SOLAR_PERFORMANCE_ANALYTICS
  TABLES (
    plants AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'solar plants', 'solar farms', 'PV plants', 'sites')
      COMMENT = 'One row per solar plant (entity), 90-day totals',
    risk AS ML.LOSS_EVENT_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day generation loss event probability per plant',
    causes AS CURATED.LOSS_EVENT_CAUSES PRIMARY KEY (ROOT_CAUSE)
      COMMENT = 'Generation loss events by root cause, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_plant AS risk (ENTITY_ID) REFERENCES plants)
  FACTS (
    plants.in_range_f AS IN_RANGE_READINGS,
    plants.readings_f AS INVERTER_READINGS,
    plants.checks_f AS STRING_CHECKS,
    plants.faults_f AS STRING_FAULTS,
    plants.loss_events_f AS LOSS_EVENT_COUNT,
    plants.downtime_hours_f AS DOWNTIME_HOURS,
    plants.operating_hours_f AS OPERATING_HOURS,
    plants.planned_hours_f AS PLANNED_HOURS,
    risk.loss_event_prob_f AS LOSS_EVENT_PROB_7D,
    causes.cause_loss_events_f AS LOSS_EVENT_COUNT,
    causes.cause_out_of_range_f AS OUT_OF_RANGE_READINGS,
    causes.cause_hours_f AS DOWNTIME_HOURS,
    daily.day_in_range_f AS IN_RANGE_READINGS,
    daily.day_readings_f AS INVERTER_READINGS,
    daily.day_loss_events_f AS LOSS_EVENT_COUNT
  )
  DIMENSIONS (
    plants.plant_id AS ENTITY_ID WITH SYNONYMS = ('plant', 'entity', 'entity id', 'plant code'),
    plants.plant_name AS ENTITY_NAME,
    plants.region AS REGION WITH SYNONYMS = ('region', 'city', 'province', 'solar hub') COMMENT = 'Vietnam city',
    plants.plant_type AS CATEGORY WITH SYNONYMS = ('plant type', 'mounting type', 'category'),
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    causes.root_cause AS ROOT_CAUSE,
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    plants.plant_count AS COUNT(plants.plant_id) WITH SYNONYMS = ('number of entities', 'entity count', 'number of plants'),
    plants.in_range_reading_pct AS 100 * SUM(plants.in_range_f) / NULLIF(SUM(plants.readings_f), 0)
      WITH SYNONYMS = ('in-range rate', 'performance ratio compliance') COMMENT = 'In-range inverter readings / inverter readings',
    plants.total_loss_events AS SUM(plants.loss_events_f) WITH SYNONYMS = ('generation loss events', 'loss events'),
    plants.string_faults_per_1k AS 1000 * SUM(plants.faults_f) / NULLIF(SUM(plants.checks_f), 0),
    plants.total_inverter_readings AS SUM(plants.readings_f) WITH SYNONYMS = ('reading volume', 'SCADA readings'),
    plants.total_string_checks AS SUM(plants.checks_f),
    plants.plant_availability_rate AS 100 * SUM(plants.operating_hours_f) / NULLIF(SUM(plants.planned_hours_f), 0),
    plants.total_downtime_hours AS SUM(plants.downtime_hours_f),
    risk.avg_loss_event_prob AS AVG(risk.loss_event_prob_f),
    causes.cause_loss_events AS SUM(causes.cause_loss_events_f),
    causes.cause_out_of_range_readings AS SUM(causes.cause_out_of_range_f),
    causes.cause_downtime_hours AS SUM(causes.cause_hours_f),
    daily.daily_in_range_pct AS 100 * SUM(daily.day_in_range_f) / NULLIF(SUM(daily.day_readings_f), 0),
    daily.daily_inverter_readings AS SUM(daily.day_readings_f),
    daily.daily_loss_events AS SUM(daily.day_loss_events_f)
  )
  COMMENT = 'Synthetic Vietnam solar plant performance analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.SOLAR_PERFORMANCE_AGENT
  COMMENT = 'Solar performance assistant over a synthetic Vietnam solar plant fleet'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give plant IDs and numbers with units."
  orchestration: "Use solar_performance_analyst for in-range inverter readings, generation loss events, string faults, reading volume, plants, regions, risk and root causes. Use sop_search for generation loss response procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: solar_performance_analyst
      description: "In-range inverter readings, generation loss events, faults per 1,000 string checks, inverter-reading volume, plant availability, root causes and event-risk scores per plant"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic generation loss response SOPs by plant type and cause"
tool_resources:
  solar_performance_analyst:
    semantic_view: __DEMO_DB__.APP.SOLAR_PERFORMANCE_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.PLANT_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-telemetry alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), PLANT_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, INVERTER_TEMP_C FLOAT, INVERTER_LOAD_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION VN_RENEWABLE_SOLAR_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALARMS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (PLANT_ID, EVENT_TS, INVERTER_TEMP_C, INVERTER_LOAD_PCT, SOP_HINT)
    SELECT t.PLANT_ID, t.EVENT_TS, t.INVERTER_TEMP_C, t.INVERTER_LOAD_PCT,
           'Check ' || h.CATEGORY || ' SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_TELEMETRY t
    JOIN RAW.PLANTS h ON h.ID = t.PLANT_ID
    LEFT JOIN ML.LOSS_EVENT_RISK_SCORES r ON r.ENTITY_ID = t.PLANT_ID
    WHERE t.STATUS = 'ALARM'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.PLANT_ID = t.PLANT_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('VN_RENEWABLE_SOLAR_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Vietnam solar plant inverter alarm',
      'New live-telemetry alarms logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_ALARM_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_TELEMETRY t
    WHERE t.STATUS = 'ALARM'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.PLANT_ID = t.PLANT_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALARMS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.LOSS_EVENT_CAUSES REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.LOSS_EVENT_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.LOSS_EVENT_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.LOSS_EVENT_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'AGE_YEARS', AGE_YEARS, 'INVERTER_TEMP_C', INVERTER_TEMP_C,
             'INVERTER_LOAD_PCT', INVERTER_LOAD_PCT, 'INVERTER_TEMP_7D', INVERTER_TEMP_7D, 'LOSS_EVENTS_30D', LOSS_EVENTS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:LOSS_EVENT::FLOAT, 4) AS LOSS_EVENT_PROB_7D,
         CASE WHEN PRED:probability:LOSS_EVENT::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:LOSS_EVENT::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
