# Solar Farm Analytics

**Vietnam - Renewable Energy**
Use case: Solar Farm Analytics

> Solar Farm Analytics for Vietnam - ML.FORECAST and Dynamic Tables power real-time solar farm analytics intelligence for renewable energy in Ninh Thuan & Binh Thuan.

## Why Snowflake

Snowflake delivers solar farm analytics intelligence for Vietnamese renewable energy - Dynamic Tables maintain real-time dashboards, ML.FORECAST projects key metrics, and Cortex AI generates recommendations

- **ML.FORECAST for solar farm analytics** - Only demo for Vietnamese renewable energy
- **ML.ANOMALY_DETECTION early warning** - Detects deviations before impact
- **AI recommendations** - Cortex AI actionable guidance
- **Vietnamese context** - Local names, VND economics

## What is deployed

| | |
|---|---|
| Database | `VIETNAM_RENEWABLE_SOLAR` |
| Service | `VIETNAM_RENEWABLE_SOLAR_APP` |
| Compute pool | `SEA_DEMOS_VIETNAM_POOL` |
| Dimension table | `RAW.SOLAR_SITES` (20 rows) |
| Fact table | `RAW.GENERATION_READINGS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | VND (₫) |

Regions in play: Ho Chi Minh City, Hanoi, Binh Duong, Dong Nai, Can Tho
Segments: Utility Scale, Rooftop Commercial, Floating Solar, Agrivoltaic

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh VIETNAM_RENEWABLE_SOLAR
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Solar Generation | `847 GWh` | average per event |
| Capacity Factor | `18.4%` | total across Solar Sites |
| Curtailment | `12%` | average per event |
| Plants Active | `42` | total across Solar Sites |
| Tomorrow Forecast | `24.2 GWh` | average per event |
| Irradiance Index | `5.4 kWh/m²` | average per event |
| Degradation Rate | `0.5%/yr` | average per event |


## Demo flow

1. Overview
2. Analytics
3. AI Intelligence
4. Ask AI
5. Architecture

## Talking points

- **100K operations** - tracked in Ninh Thuan & Binh Thuan
- **500K metrics** - time-series data points
- **5K assets** - monitored
- **100 docs** - searchable

## Business impact

- Vietnam renewable energy sector growing rapidly (GSO Vietnam)
- AI improves outcomes 15-30% (McKinsey)
- Vietnam FDI strong in this sector (MPI)
- Real-time analytics reduces response 60-80% (Gartner)

---
Generated from `generator/demo_specs/aws-vietnam-renewable-solar.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-vietnam-renewable-solar` instead.
