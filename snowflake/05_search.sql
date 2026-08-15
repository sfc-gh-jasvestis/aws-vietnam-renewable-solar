-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Solar Farm Analytics
-- ============================================================================
USE DATABASE SOLAR_ANALYTICS;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.SOLAR_ANALYTICS_SEARCH
  ON CONTENT
  ATTRIBUTES DOC_TYPE, CATEGORY
  WAREHOUSE = SOLAR_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.DOCUMENTS
);
