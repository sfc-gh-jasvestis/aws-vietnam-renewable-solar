# Vietnam Solar Plant Performance Monitor

**Vietnam - Renewable Energy Solar Plant Performance**
Use case: In-range inverter readings, inverter traceability and generation loss event risk

> Solar performance monitoring for a fictional solar operator's fleet of 30 plants across 6 Vietnam cities (ground-mount fixed-tilt, single-axis tracker, floating, rooftop C&I and solar-plus-storage): dynamic tables, a holdout-evaluated event-risk classifier, an inverter-reading volume forecast and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile in-range inverter readings, string faults and plant availability from RAW plant data, with checks in `run_core.py`
- **Event-risk classification** gives a holdout-evaluated next-7-day generation loss event probability per plant
- **Inverter-reading volume forecast** projects 14 days of fleet-wide inverter readings with prediction intervals
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live telemetry**: a native simulator (Snowflake only) or IoT Core, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.PLANTS` (30 rows) |
| Fact table | `RAW.PLANT_DAILY` (2,700 plant-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `LOSS_EVENT_CAUSES`, `TREND_ANALYSIS` |
| ML | `ML.LOSS_EVENT_RISK_SCORES`, `ML.LOSS_EVENT_RISK_HOLDOUT_METRICS`, `ML.VOLUME_FORECAST`, `ML.INVERTER_TEMP_ANOMALIES` |

Cities: Phan Rang-Thap Cham, Phan Thiet, Tay Ninh, Cam Ranh, Buon Ma Thuot, Quy Nhon.
Plant types: Ground-Mount Fixed Tilt, Single-Axis Tracker, Floating Solar, Rooftop C&I, Solar-plus-Storage.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| In-Range Inverter Readings | 90.0% |
| Generation Loss Events | 427 |
| Faults per 1k String Checks | 18.74 |
| Inverter Readings | 1,122,131 |
| Plant Availability | 98.1% |
| Solar Plants | 30 |
| Spare Parts Readiness | 82.2% |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily in-range inverter readings, out-of-range readings by loss cause, plant table
2. Predictive: holdout metrics, risk bands, 14-day inverter-reading volume forecast, peak inverter temperature anomalies
3. Plant Health: plant availability, spare-parts readiness, module-cleaning PM compliance against in-range inverter readings, then generate the action memo
4. Live IoT: run `CALL APP.SIMULATE_TELEMETRY(20)` (Snowflake only) or `python aws/publish_telemetry.py --count 20` (AWS build: IoT Core, S3, Snowpipe). Then run `EXECUTE ALERT APP.LIVE_ALARM_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- Per-plant in-range rate ranges from 85.6% to 92.6%. Tay Ninh is the lowest city, at 87.9%.
- Tracker motor faults push the most inverter readings out of range of the 14 loss causes.
- The risk model is evaluated on a time-based holdout: precision 0.66 and recall 0.69 at 0.5, against a 0.54 base rate. Present it as triage, not a guarantee.
- The Phan Thiet grid curtailment and the Buon Ma Thuot monsoon storm outage are excluded from event labels, because they are city-wide events, not plant-driven.
- Inverter traceability: SOPs require logging the affected inverter and string IDs and confirming SCADA values with a handheld check, and each plant-day records in-range readings and performance ratio.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
