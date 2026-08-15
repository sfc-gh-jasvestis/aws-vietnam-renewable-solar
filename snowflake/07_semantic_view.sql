-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Solar Farm Analytics
-- ============================================================================
USE DATABASE SOLAR_ANALYTICS;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.SOLAR_ANALYTICS_ANALYTICS
  COMMENT = 'Renewable Energy solar farm analytics analytics'
AS
  TABLES (
    CURATED.PERFORMANCE_DASHBOARD AS performance_dashboard,CURATED.TREND_ANALYTICS AS trend_analytics,CURATED.FORECAST_INPUT AS forecast_input,CURATED.OPERATIONAL_RISK AS operational_risk
  );
