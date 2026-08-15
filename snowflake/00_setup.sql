-- ============================================================================
-- Solar Farm Analytics
-- Solar Farm Analytics for Vietnam - ML.FORECAST and Dynamic Tables power real-time solar farm analytics intelligence for renewable energy in Ninh Thuan & Binh Thuan.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS SOLAR_ANALYTICS;
CREATE WAREHOUSE IF NOT EXISTS SOLAR_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE SOLAR_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE SOLAR_WH;
