-- Synthetic plant-day solar generation observations for a fictional Vietnam solar operator.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild is
-- reproducible: per-plant inverter fleet size, plant age and loss-event propensity,
-- inverter-reading volume from a weekly module-washing day and a clear-sky irradiance
-- peak, soiling between module-cleaning (PM) visits, plant-type-weighted generation
-- loss causes, and two regional events.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.PLANTS AS
WITH plants AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS PLANT_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 30))
), draws AS (
  SELECT PLANT_INDEX,
         MOD(ABS(HASH(PLANT_INDEX, 'vnsolar-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(PLANT_INDEX, 'vnsolar-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(PLANT_INDEX, 'vnsolar-pm')), 1000000) / 1e6 AS U_PM,
         MOD(ABS(HASH(PLANT_INDEX, 'vnsolar-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(PLANT_INDEX, 'vnsolar-capacity')), 1000000) / 1e6 AS U_CAPACITY
  FROM plants
)
SELECT 'SP-' || LPAD(PLANT_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic solar plant ' || LPAD(PLANT_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (7 and 5 are coprime): every city and plant type is
       -- present, with Phan Rang-Thap Cham the largest solar hub.
       CASE MOD(PLANT_INDEX, 7) WHEN 0 THEN 'Phan Rang-Thap Cham' WHEN 1 THEN 'Phan Rang-Thap Cham'
            WHEN 2 THEN 'Phan Thiet' WHEN 3 THEN 'Tay Ninh' WHEN 4 THEN 'Cam Ranh'
            WHEN 5 THEN 'Buon Ma Thuot' ELSE 'Quy Nhon' END AS REGION,
       CASE MOD(PLANT_INDEX, 5) WHEN 0 THEN 'Ground-Mount Fixed Tilt' WHEN 1 THEN 'Single-Axis Tracker'
            WHEN 2 THEN 'Floating Solar' WHEN 3 THEN 'Rooftop C&I' ELSE 'Solar-plus-Storage' END AS CATEGORY,
       PLANT_INDEX,
       ROUND(1 + U_AGE * 9, 1) AS AGE_YEARS,
       -- Base daily loss-event probability 0.8%-3.4%; ~15% of plants are chronic (x3).
       (0.008 + U_RATE * 0.026) * IFF(U_RATE > 0.85, 3, 1) AS BASE_LOSS_EVENT_RATE,
       10 * (1 + FLOOR(U_PM * 3)) AS PM_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.42 AS PM_COMPLETION_PROB,
       ROUND(CASE MOD(PLANT_INDEX, 5) WHEN 0 THEN 620 WHEN 1 THEN 780 WHEN 2 THEN 430
                  WHEN 3 THEN 260 ELSE 510 END * (0.8 + U_CAPACITY * 0.4)) AS DAILY_CAPACITY,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.PLANT_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), regional_events AS (
  -- Two city-wide events in the window.
  SELECT * FROM VALUES (31, 'Phan Thiet', 'Grid curtailment', 6.0),
                       (66, 'Buon Ma Thuot', 'Monsoon storm outage', 9.0)
    AS o(DAY_INDEX, REGION, EVENT_CAUSE, HOURS)
), base AS (
  SELECT h.ID AS ENTITY_ID, h.PLANT_INDEX, h.CATEGORY, h.REGION, h.AGE_YEARS,
         h.BASE_LOSS_EVENT_RATE, h.PM_INTERVAL_DAYS, h.PM_COMPLETION_PROB, h.DAILY_CAPACITY,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         24.0 AS PLANNED_HOURS,
         MOD(d.DAY_INDEX + h.PLANT_INDEX * 3, h.PM_INTERVAL_DAYS) AS DAYS_SINCE_PM,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnsolar-evt')), 1000000) / 1e6 AS U_EVT,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnsolar-down')), 1000000) / 1e6 + 1e-6 AS U_DOWN,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnsolar-cause')), 1000000) / 1e6 AS U_CAUSE,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnsolar-pmdone')), 1000000) / 1e6 AS U_PMDONE,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnsolar-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnsolar-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnsolar-hit')), 1000000) / 1e6 AS U_HIT,
         e.EVENT_CAUSE, e.HOURS AS EVENT_HOURS
  FROM RAW.PLANTS h CROSS JOIN days d
  LEFT JOIN regional_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = h.REGION
), loaded AS (
  SELECT *,
         IFF(DAYS_SINCE_PM = 0, 1, 0) AS PM_DUE,
         IFF(DAYS_SINCE_PM = 0 AND U_PMDONE < PM_COMPLETION_PROB, 1, 0) AS PM_COMPLETED,
         -- Soiling and inverter wear rise between cleaning visits; weak PM discipline carries them over.
         DAYS_SINCE_PM / PM_INTERVAL_DAYS + (1 - PM_COMPLETION_PROB) AS WEAR,
         -- Heat episode (high ambient temperature): 6 of every 19 days per plant (staggered).
         IFF(MOD(DAY_INDEX + PLANT_INDEX * 4, 19) < 6, 1, 0) AS STRESS,
         -- Volume: a weekly module-washing day takes strings offline, and a clear-sky
         -- irradiance peak on day 52 (+31%) eases over 3 days.
         ROUND(DAILY_CAPACITY * (0.70 + 0.25 * U_VOLUME)
               * IFF(MOD(DAY_INDEX, 7) = 5, 0.81, 1.0)
               * CASE DAY_INDEX - 52 WHEN 0 THEN 1.31 WHEN 1 THEN 1.18 WHEN 2 THEN 1.07 ELSE 1.0 END) AS INVERTER_READINGS
  FROM base
), events AS (
  SELECT *, INVERTER_READINGS / DAILY_CAPACITY AS LOAD_RATIO,
         LEAST(0.5, BASE_LOSS_EVENT_RATE * (0.4 + 1.6 * WEAR) * (0.3 + INVERTER_READINGS / DAILY_CAPACITY)
                    * (1 + AGE_YEARS / 15) * (1 + 3.0 * STRESS)) AS P_EVT
  FROM loaded
), counted AS (
  SELECT *,
         CASE WHEN EVENT_HOURS IS NOT NULL THEN 1
              WHEN U_EVT < P_EVT / 4 THEN 2
              WHEN U_EVT < P_EVT THEN 1
              ELSE 0 END AS LOSS_EVENT_COUNT
  FROM events
), timed AS (
  SELECT *,
         -- Unavailable hours: exponential, mean depends on plant type.
         CASE WHEN LOSS_EVENT_COUNT = 0 THEN 0.0
              WHEN EVENT_HOURS IS NOT NULL THEN EVENT_HOURS
              ELSE LEAST(20.0, ROUND(LOSS_EVENT_COUNT * (0.5 - LN(U_DOWN) *
                   CASE CATEGORY WHEN 'Ground-Mount Fixed Tilt' THEN 2.4 WHEN 'Single-Axis Tracker' THEN 2.9
                                 WHEN 'Floating Solar' THEN 2.1 WHEN 'Rooftop C&I' THEN 1.8 ELSE 2.6 END), 1))
         END AS DOWNTIME_HOURS,
         -- In-range rate (inverter readings whose performance ratio sits inside the
         -- expected band for the plant type): base by plant type, minus soiling and
         -- overload, minus the event hit.
         LEAST(0.995, GREATEST(0.50,
           CASE CATEGORY WHEN 'Ground-Mount Fixed Tilt' THEN 0.956 WHEN 'Single-Axis Tracker' THEN 0.947
                         WHEN 'Floating Solar' THEN 0.962 WHEN 'Rooftop C&I' THEN 0.941 ELSE 0.952 END
             - 0.034 * WEAR - 0.05 * GREATEST(0, LOAD_RATIO - 0.9) - 0.012 * U_NOISE
             - LOSS_EVENT_COUNT * (0.06 + 0.14 * U_HIT))) AS IN_RANGE_RATE
  FROM counted
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE, PLANNED_HOURS, DOWNTIME_HOURS,
       PLANNED_HOURS - DOWNTIME_HOURS AS OPERATING_HOURS,
       LOSS_EVENT_COUNT,
       CASE WHEN LOSS_EVENT_COUNT = 0 THEN 'None'
            WHEN EVENT_CAUSE IS NOT NULL THEN EVENT_CAUSE
            WHEN CATEGORY = 'Ground-Mount Fixed Tilt' THEN IFF(U_CAUSE < 0.45, 'Inverter overtemperature derate', IFF(U_CAUSE < 0.75, 'Module soiling loss', 'String fuse failure'))
            WHEN CATEGORY = 'Single-Axis Tracker' THEN IFF(U_CAUSE < 0.5, 'Tracker motor fault', IFF(U_CAUSE < 0.8, 'Tracker controller comms loss', 'Wind stow event'))
            WHEN CATEGORY = 'Floating Solar' THEN IFF(U_CAUSE < 0.55, 'Cable insulation fault', 'Bird-dropping soiling')
            WHEN CATEGORY = 'Rooftop C&I' THEN IFF(U_CAUSE < 0.6, 'Inverter cooling fan failure', 'Partial shading')
            ELSE IFF(U_CAUSE < 0.55, 'Battery PCS fault', 'Irradiance sensor drift') END AS ROOT_CAUSE,
       PM_DUE, PM_COMPLETED,
       INVERTER_READINGS,
       FLOOR(INVERTER_READINGS * IN_RANGE_RATE) AS IN_RANGE_READINGS,
       ROUND(INVERTER_READINGS * (3.5 + U_VOLUME * 1.5)) AS STRING_CHECKS,
       ROUND(INVERTER_READINGS * (3.5 + U_VOLUME * 1.5) * (0.004 + 0.013 * WEAR + 0.024 * LOSS_EVENT_COUNT + 0.004 * U_NOISE)) AS STRING_FAULTS,
       -- Peak inverter heatsink temperature (deg C): rises with wear, overload, heat episodes and events.
       ROUND(46.0 + 5.5 * WEAR + 7.0 * GREATEST(0, LOAD_RATIO - 0.8) + 4.8 * STRESS + 6.5 * LOSS_EVENT_COUNT + U_NOISE * 2.2, 2) AS INVERTER_TEMP_C,
       ROUND(LEAST(100, 100 * LOAD_RATIO * (0.78 + 0.14 * U_NOISE) + 7 * STRESS + 6 * LOSS_EVENT_COUNT), 1) AS INVERTER_LOAD_PCT,
       ROUND(68.0 + 16.0 * IN_RANGE_RATE + 1.8 * U_NOISE, 1) AS PERFORMANCE_RATIO_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM timed;

-- Spare-parts readiness per plant (snapshot): units required versus on hand.
CREATE TABLE RAW.EQUIPMENT_READINESS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Ground-Mount Fixed Tilt' THEN 'Spare string inverter' WHEN 'Single-Axis Tracker' THEN 'Tracker drive motor'
                     WHEN 'Floating Solar' THEN 'Pontoon float kit' WHEN 'Rooftop C&I' THEN 'Inverter cooling fan'
                     ELSE 'Battery module' END AS EQUIPMENT_TYPE,
       4 + MOD(ABS(HASH(ID, 'vnsolar-req')), 19) AS REQUIRED_QTY,
       FLOOR((4 + MOD(ABS(HASH(ID, 'vnsolar-req')), 19)) * (0.66 + MOD(ABS(HASH(ID, 'vnsolar-avail')), 1000) / 1000 * 0.38)) AS ON_HAND_QTY,
       MOD(ABS(HASH(ID, 'vnsolar-order')), 4) AS ON_ORDER_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.PLANTS;
