-- Generated from generator/demo_specs/aws-vietnam-renewable-solar.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-vietnam-renewable-solar
-- This is the schema that is actually deployed for VIETNAM_RENEWABLE_SOLAR.

-- VIETNAM_RENEWABLE_SOLAR  (Solar Farm Analytics)
-- generated from generator/demo_specs/aws-vietnam-renewable-solar.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS VIETNAM_RENEWABLE_SOLAR;
CREATE SCHEMA IF NOT EXISTS VIETNAM_RENEWABLE_SOLAR.RAW;
CREATE SCHEMA IF NOT EXISTS VIETNAM_RENEWABLE_SOLAR.CURATED;
CREATE SCHEMA IF NOT EXISTS VIETNAM_RENEWABLE_SOLAR.APP;
USE DATABASE VIETNAM_RENEWABLE_SOLAR;

-- 5 real regions; entity names carry their region so the two always agree
