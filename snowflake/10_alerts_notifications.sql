-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Solar Farm Analytics
-- ============================================================================
USE DATABASE SOLAR_ANALYTICS;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_vietnam_renewable_solar_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: PERFORMANCE_ALERT
CREATE OR REPLACE ALERT APP.PERFORMANCE_ALERT
  WAREHOUSE = SOLAR_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Solar Farm Analytics performance below threshold'
IF (EXISTS (
  SELECT 1 FROM CURATED.PERFORMANCE_DASHBOARD
  WHERE 1=1 -- Condition: Key metric below threshold
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_vietnam_renewable_solar_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Solar Farm Analytics: Solar Farm Analytics performance below threshold',
    'Solar Farm Analytics performance below threshold'
  );

ALTER ALERT APP.PERFORMANCE_ALERT RESUME;

-- Alert: ANOMALY_ALERT
CREATE OR REPLACE ALERT APP.ANOMALY_ALERT
  WAREHOUSE = SOLAR_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Anomalous pattern detected'
IF (EXISTS (
  SELECT 1 FROM CURATED.PERFORMANCE_DASHBOARD
  WHERE 1=1 -- Condition: ML detects anomaly
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_vietnam_renewable_solar_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Solar Farm Analytics: Anomalous pattern detected',
    'Anomalous pattern detected'
  );

ALTER ALERT APP.ANOMALY_ALERT RESUME;

