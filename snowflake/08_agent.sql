-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Solar Farm Analytics
-- ============================================================================
USE DATABASE SOLAR_ANALYTICS;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.SOLAR_ANALYTICS_AGENT
  COMMENT = 'Solar Farm Analytics AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'SOLAR_ANALYTICS.APP.SOLAR_ANALYTICS_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'SOLAR_ANALYTICS.SEARCH.SOLAR_ANALYTICS_SEARCH', TOOL_DESCRIPTION => 'Search documents for Renewable Energy information')
  )
  SYSTEM_PROMPT = 'You are the Solar Farm Analytics Agent for Vietnamese renewable energy operations in Ninh Thuan & Binh Thuan.';
