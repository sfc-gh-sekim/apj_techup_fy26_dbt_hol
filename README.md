# TechUP FY26 - dbt Workspaces Hands-On Lab
## Singapore Taxi Availability Data Transformation Pipeline

This hands-on lab demonstrates how to use **dbt Projects on Snowflake** (Workspaces) to build a data transformation pipeline using real-time Singapore transportation and location data. Learn how to transform raw GeoJSON data into structured, queryable datasets using dbt Core directly within Snowflake.

> 📚 **Reference Documentation**: [dbt Projects on Snowflake](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Data Models](#data-models)
- [Key Concepts](#key-concepts)
- [Additional Resources](#additional-resources)

---

## 🎯 Overview

This lab teaches you how to:
- ✅ Use **dbt Workspaces** in Snowflake (Preview Feature)
- ✅ Transform raw GeoJSON data into structured tables
- ✅ Create **Dynamic Tables** as dbt models
- ✅ Build a **medallion architecture** (Bronze → Silver → Gold)
- ✅ Work with **Singapore open data** (real-time taxi locations, hawker centres, MRT stations)
- ✅ Leverage Snowflake's **GEOGRAPHY** data type for spatial data
- ✅ Use **Git integration** for version control
- ✅ Deploy dbt projects directly in Snowflake

### What You'll Build

A data pipeline that processes:
- 🚕 **Real-time taxi availability** (updated every minute)
- 🍜 **Hawker centres** locations and details
- 🚇 **MRT station exits** with coordinates
- 🏛️ **Tourist attractions** with metadata
- 🌤️ **Weather forecasts** (2-hour predictions)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Bronze Layer (Raw Data)                                        │
│  APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET.RAW_DATA              │
│  - taxi_availability (GeoJSON, every 1 min)                    │
│  - hawker_centres (GeoJSON, daily)                             │
│  - lta_mrt_station_exit (GeoJSON, daily)                       │
│  - tourist_attractions (GeoJSON, daily)                        │
│  - weather_forecast_2h (JSON, every 30 min)                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────┐
                    │   dbt Models    │
                    │  (Workspaces)   │
                    └─────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Silver Layer (Cleaned & Structured)                            │
│  TECHUP25.DBT_HOL_SILVER                                        │
│  - taxi_availability (lat/long as GEOGRAPHY)                    │
│  - taxi_availability_metadata (timestamps & counts)             │
│  - hawker_centres (parsed properties)                           │
│  - mrt_station_exits (extracted from HTML)                      │
│  - tourist_attractions (structured attributes)                  │
│                                                                  │
│  Materialized as: DYNAMIC TABLES                                │
│  Refresh: target_lag = downstream / 1 minute                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Gold Layer (Business Logic & Aggregations)                     │
│  TECHUP25.DBT_HOL_GOLD                                          │
│  - [Your aggregated models here]                                │
│                                                                  │
│  Materialized as: DYNAMIC TABLES                                │
│  Refresh: target_lag = 24 HOURS                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

Ready to get started? Follow the detailed setup instructions:

📖 **[Complete Setup Guide →](SETUP.md)**

**Quick Overview:**
1. 📊 Access Singapore taxi dataset from private listing
2. 🏗️ Run setup script to create Snowflake environment
3. 🔗 Create dbt Workspace connected to Git
4. ▶️ Run silver and gold layer transformations
5. 📈 View data lineage and explore results

**Prerequisites:**
- Snowflake account (Enterprise Edition or higher)
- `ACCOUNTADMIN` privileges for initial setup
- Basic understanding of SQL and dbt concepts

---

## 📂 Project Structure

```
apj_techup_fy26_dbt_hol/
│
├── dbt_project.yml           # Project configuration & materialization settings
├── profiles.yml              # Connection profiles (silver, gold targets)
├── setup.sql                 # Initial Snowflake setup script
│
├── models/
│   ├── _sources.yml          # Source table definitions from raw data
│   │
│   ├── silver/               # 🥈 Silver Layer - Cleaned & Structured
│   │   ├── _schema.yml       # Model documentation & tests
│   │   ├── hawker_centres.sql
│   │   ├── mrt_station_exits.sql
│   │   ├── taxi_availability.sql
│   │   ├── taxi_availability_metadata.sql
│   │   ├── tourist_attractions.sql
│   │   └── all_locations.sql # Unified location data with unique IDs
│   │
│   └── gold/                 # 🥇 Gold Layer - Business Logic
│       ├── _schema.yml
│       └── taxi_counts_by_location.sql  # Proximity analysis
│
├── macros/                   # Custom Jinja macros
├── tests/                    # Custom data tests
├── seeds/                    # CSV files to load as tables
├── snapshots/                # Type-2 SCD snapshots
├── analyses/                 # Ad-hoc analysis queries
│
└── images/                   # Documentation images
    ├── 1_marketplace.png
    ├── 2_setup.png
    ├── 3_silver.png
    ├── 4_run_silver.png
    └── 5_silver_dag.png
```

---

## 📊 Data Models

### Silver Layer Models

| Model | Source | Rows (approx) | Description |
|-------|--------|---------------|-------------|
| **taxi_availability** | `taxi_availability` | ~5,000 (latest) | Individual taxi coordinates from latest extract |
| **taxi_availability_metadata** | `taxi_availability` | ~1 (latest) | Summary stats: taxi count, timestamp, API status |
| **hawker_centres** | `hawker_centres` | ~120 | Hawker centre locations with stall counts |
| **mrt_station_exits** | `lta_mrt_station_exit` | ~500 | MRT/LRT station exit coordinates |
| **tourist_attractions** | `tourist_attractions` | ~200 | Tourist sites with descriptions and hours |
| **all_locations** | Combined | ~820 | Unified location data with unique identifiers |

### Gold Layer Models

| Model | Description | Key Metrics |
|-------|-------------|-------------|
| **taxi_counts_by_location** | Proximity analysis for all locations | Taxi counts within 100m, 500m, 1km radii |

### Potential Future Gold Models

- 📍 Taxi availability by district/region
- 🗺️ Accessibility scores (taxi + MRT proximity)  
- 🏆 Location popularity rankings
- 📊 Service level metrics by location type
- 🎯 Underserved area identification

---

## 🔑 Key Concepts

### 1️⃣ dbt Workspaces in Snowflake

**What is it?**
A web-based IDE built into Snowflake that lets you:
- Edit dbt project files directly in the browser
- Connect to Git repositories for version control
- Run dbt commands without installing dbt locally
- Deploy dbt projects as Snowflake objects
- Visualize data lineage with DAG view

**Key Commands:**
```bash
# Run all models
dbt run

# Run with specific target (silver or gold)
dbt run --target silver

# Run specific model
dbt run --select hawker_centres

# Run tests
dbt test

# View compiled SQL
dbt compile

# Show lineage
dbt docs generate
```

### 2️⃣ Dynamic Tables

**What are they?**
Dynamic Tables are Snowflake's **declarative data pipelines**:
- Automatically refresh based on `target_lag` setting
- Use incremental refresh (only process changes)
- Support complex DAG dependencies
- Handle schema evolution gracefully

**Configuration:**
```yaml
models:
  techup_dbt_hands_on_lab:
    silver:
      +materialized: dynamic_table          # Use Dynamic Tables
      +snowflake_warehouse: TECHUP25_WH    # Compute warehouse
      +target_lag: downstream               # Refresh when downstream needs it
      +refresh_mode: INCREMENTAL            # Only process changes
      +initialize: ON_CREATE                # Populate on creation
```

**Target Lag Options:**
- `downstream` - Refresh when consuming models need data (used for location data)
- `1 minute` - Refresh every minute (for real-time taxi data)
- `24 HOURS` - Daily refresh (for aggregated analytics)

### 3️⃣ Medallion Architecture

**Bronze → Silver → Gold**

| Layer | Purpose | Transformations | Materialization |
|-------|---------|-----------------|-----------------|
| **Bronze** | Raw data | None (landed as-is) | External/Base Tables |
| **Silver** | Cleaned data | Parse JSON, type cast, flatten | Dynamic Tables |
| **Gold** | Business logic | Aggregations, joins, metrics | Dynamic Tables |

### 4️⃣ Snowflake GEOGRAPHY Type

All location models use `ST_MAKEPOINT(longitude, latitude)` to create native GEOGRAPHY objects:

**Benefits:**
- 🌍 Native spatial functions (distance, containment, intersections)
- 📍 Optimized storage and indexing
- 🔍 Easy integration with mapping tools
- 🚀 Fast geospatial queries

**Example Query:**
```sql
-- Find taxi availability near hawker centres
SELECT 
    l.location_name,
    l.location_type,
    tc.taxis_within_500m,
    tc.taxi_availability_category
FROM all_locations l
JOIN taxi_counts_by_location tc ON l.location_id = tc.location_id
WHERE l.location_type = 'hawker_centre'
ORDER BY tc.taxis_within_500m DESC;
```

### 5️⃣ Data Quality Tests

Tests are defined in `_schema.yml`:

```yaml
columns:
  - name: objectid
    tests:
      - not_null       # Column cannot be NULL
      - unique         # Values must be unique
  - name: coords
    tests:
      - not_null       # Geography point must exist
```

**Run tests:**
```bash
dbt test                      # Run all tests
dbt test --select hawker_centres  # Test one model
```

---

## 📚 Additional Resources

- [dbt Projects on Snowflake Documentation](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake)
- [Snowflake Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
- [dbt Core Documentation](https://docs.getdbt.com/docs/introduction)
- [Singapore Open Data Portal](https://data.gov.sg/)
- [Snowflake Geography Functions](https://docs.snowflake.com/en/sql-reference/functions-geospatial)

---

## 🎓 Learning Objectives Achieved

By completing this lab, you've learned how to:

✅ Access and work with private data listings in Snowflake  
✅ Set up dbt Workspaces with Git integration  
✅ Transform raw GeoJSON data into structured tables  
✅ Use Dynamic Tables for automated data pipelines  
✅ Implement medallion architecture (bronze/silver/gold)  
✅ Work with Snowflake's GEOGRAPHY data type  
✅ Deploy dbt projects directly in Snowflake  
✅ Visualize data lineage with DAG views  
✅ Write data quality tests in dbt  
✅ Use database roles for access control  

---

## 🚀 Next Steps

**Want to extend this project?** Here are some ideas:

1. **📊 Build More Gold Models**: 
   - Location popularity rankings
   - Accessibility scoring
   - Service level metrics

2. **🗺️ Create Visualizations**: 
   - Streamlit app with interactive maps
   - Taxi availability heatmaps
   - Location performance dashboards

3. **🔧 Enhance Data Quality**: 
   - Custom data tests
   - Monitoring and alerting
   - Data freshness checks

4. **⚡ Optimize Performance**: 
   - Add clustering keys
   - Implement incremental models
   - Fine-tune refresh schedules

5. **🚀 Production Deployment**: 
   - CI/CD with Snowflake CLI
   - Environment management
   - Automated testing

---

## 👥 Contributors

- **TechUP FY26 APJ Team**
   - Sean Kim (sean.kim@snowflake.com)
   - Adrian Lee (adrian.lee@snowflake.com)
- Data source: [data.gov.sg](https://data.gov.sg/)

---

## 📄 License

This project is for educational purposes as part of the TechUP FY26 training program.

---

**Happy transforming! 🎉**

For questions or issues, please contact your TechUP instructor.

