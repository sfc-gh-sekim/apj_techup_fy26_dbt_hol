# Setup Instructions
## Singapore Taxi Availability Data Transformation Pipeline

This guide walks you through setting up the dbt project on Snowflake Workspaces to transform Singapore transportation and location data.

---

## ✅ Prerequisites

- Snowflake account (Enterprise Edition or higher recommended)
- `ACCOUNTADMIN` privileges (for initial setup)
- Git repository access (GitHub, GitLab, etc.)
- Basic understanding of:
  - SQL
  - dbt concepts (models, sources, tests)
  - GeoJSON format

---

## 🚀 Setup Instructions

### Step 1: Get Dataset from Private Listing

1. Navigate to **Data Products** → **Private Sharing** in Snowsight
2. Search for **"APJ TechUP FY26 - Singapore Taxi Dataset"**
3. Click on the listing: `APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET`

![Marketplace Private Listing](images/1_marketplace.png)

4. Click **"Open"** to access the shared data
5. Verify you can see these tables:
   - `HAWKER_CENTRES`
   - `LTA_MRT_STATION_EXIT`
   - `TAXI_AVAILABILITY`
   - `TOURIST_ATTRACTIONS`

> 💡 **Note**: This is a **private listing** shared specifically for this lab. The data is continuously updated from Singapore's data.gov.sg APIs.

---

### Step 2: Run Initial Setup

1. Open a **SQL Worksheet** in Snowsight
2. Copy the contents of [`setup.sql`](setup.sql)
3. **Update line 47** with your GitHub username:
   ```sql
   API_ALLOWED_PREFIXES = ('https://github.com/<YOUR_GITHUB_USERNAME>')
   ```
4. Run the entire script

![Setup SQL Execution](images/2_setup.png)

**What This Script Does:**

✅ Creates database `TECHUP25` and warehouse `TECHUP25_WH`  
✅ Creates role `TECHUP25_RL` with appropriate privileges  
✅ Creates schemas:
   - `DBT_HOL_SILVER` - for cleaned, structured data
   - `DBT_HOL_GOLD` - for aggregated, business-ready data
   - `PROJECTS` - for dbt project objects and Streamlit apps

✅ Creates database roles:
   - `DBT_HOL_TRANSFORM` - for running dbt transformations
   - `DBT_HOL_READER` - for reading gold layer data

✅ Sets up **Git API Integration** for connecting to your repository

---

### Step 3: Create Workspace from Git

1. In Snowsight, navigate to **Projects** → **Workspaces**
2. Click **"+ Workspace"** → **"Create from Git Repository"**
3. Fill in the details:

   | Field | Value |
   |-------|-------|
   | **Repository URL** | `https://github.com/<your-username>/apj_techup_fy26_dbt_hol` |
   | **Workspace name** | `apj_techup_fy26_dbt_hol` |
   | **API Integration** | `MY_GIT_API_INTEGRATION` |
   | **Authentication** | Public repository (no token needed) |

4. Click **"Create"**

![Create Workspace](images/2_setup.png)

5. Wait for the workspace to initialize (should take ~30 seconds)
6. You should see the project files load in the left sidebar

---

### Step 4: Understanding the Silver Layer

The **Silver Layer** contains cleaned and structured data models. Navigate to the `models/silver/` folder in your workspace:

![Silver Layer Files](images/3_silver.png)

#### 📁 Silver Layer Files

| File | Purpose |
|------|---------|
| **`_schema.yml`** | Defines model documentation, tests, and column descriptions |
| **`hawker_centres.sql`** | Transforms raw GeoJSON into structured hawker centre data |
| **`mrt_station_exits.sql`** | Extracts MRT station exit information from HTML descriptions |
| **`taxi_availability.sql`** | Flattens coordinate arrays into individual taxi location records |
| **`taxi_availability_metadata.sql`** | Extracts summary statistics (timestamp, taxi count, API status) |
| **`tourist_attractions.sql`** | Parses tourist attraction details from HTML descriptions |
| **`all_locations.sql`** | Unified location data with unique identifiers |

#### 🔍 Example Transformation: `taxi_availability.sql`

This model transforms raw GeoJSON taxi data into a flat table:

```sql
select 
    ta.DATA:features[0]:properties:timestamp::timestamp as timestamp_sgt
    , st_makepoint(f.value[0], f.value[1]) as taxi_coords
from {{ source('raw_data', 'taxi_availability') }} ta
    , lateral flatten(input => ta.DATA:features[0]:geometry:coordinates) f
qualify rank() over (order by retrieved_at desc) = 1
```

**What it does:**
1. Extracts the timestamp from the GeoJSON properties
2. Flattens the coordinate array (each taxi has [longitude, latitude])
3. Uses `ST_MAKEPOINT()` to create Snowflake GEOGRAPHY objects
4. Uses `qualify` to get only the latest data extract

#### 🔍 Example Transformation: `hawker_centres.sql`

```sql
select 
    f.value:properties:OBJECTID::varchar as objectid
    , f.value:properties:NAME::varchar as name
    , f.value:properties:ADDRESS_MYENV::varchar as address
    , f.value:properties:ADDRESSSTREETNAME::varchar as street_name
    , f.value:properties:ADDRESSPOSTALCODE::varchar as postcode
    , f.value:properties:NUMBER_OF_COOKED_FOOD_STALLS::int as num_cooked_food_stalls
    , f.value:properties:PHOTOURL::varchar as photo_url
    , st_makepoint(f.value:geometry:coordinates[0], f.value:geometry:coordinates[1]) as coords
from {{ source('raw_data', 'hawker_centres') }} hc
    , lateral flatten(input => hc.DATA:features) f
qualify rank() over (order by retrieved_at desc) = 1
```

**What it does:**
1. Flattens the GeoJSON features array
2. Extracts all relevant properties (name, address, stalls count)
3. Creates GEOGRAPHY point from coordinates
4. Gets only the latest data extract

#### 🎯 Key Transformation Techniques

1. **LATERAL FLATTEN** - Unnests arrays in VARIANT columns
2. **ST_MAKEPOINT()** - Converts coordinates to GEOGRAPHY type
3. **REGEX_SUBSTR()** - Extracts data from HTML descriptions
4. **Type Casting** - Converts VARIANT to specific data types
5. **dbt Sources** - References raw tables using `{{ source() }}`
6. **QUALIFY** - Filters to latest data extract only

---

### Step 5: Run the dbt Project

1. In your workspace, set the **Profile** to `silver` (top right dropdown)
2. Click the **Run** button (or press ▶️)
3. In the command dropdown, select: `run --target silver`

![Run dbt Project](images/4_run_silver.png)

4. Click **Execute**

**What Happens:**

```bash
execute dbt project from workspace USERS.PUBLIC.apj_techup_fy26_dbt_hol 
  args='run --target silver'
```

The dbt engine will:
1. ✅ Parse your dbt project (`dbt_project.yml`)
2. ✅ Compile SQL models with Jinja templates
3. ✅ Run data quality tests (defined in `_schema.yml`)
4. ✅ Create **6 Dynamic Tables** in `TECHUP25.DBT_HOL_SILVER`:
   - `hawker_centres`
   - `mrt_station_exits`
   - `taxi_availability`
   - `taxi_availability_metadata`
   - `tourist_attractions`
   - `all_locations`

5. ✅ Display execution results with timing

**Expected Output:**
```
[SUCCESS 1 in 1.86s] - hawker_centres
[SUCCESS 1 in 1.85s] - mrt_station_exits
[SUCCESS 1 in 1.10s] - taxi_availability
[SUCCESS 1 in 1.23s] - taxi_availability_metadata
[SUCCESS 1 in 1.28s] - tourist_attractions
[SUCCESS 1 in 1.15s] - all_locations

Completed successfully
Done. PASS=6 WARN=0 ERROR=0 SKIP=0 TOTAL=6
```

> 🎉 **Congratulations!** You've successfully deployed your first dbt project in Snowflake Workspaces!

---

### Step 6: Run the Gold Layer

1. Change the **Profile** to `gold` (top right dropdown)
2. Click the **Run** button
3. In the command dropdown, select: `run --target gold`
4. Click **Execute**

This will create the **Gold Layer** models in `TECHUP25.DBT_HOL_GOLD`:
- `taxi_counts_by_location` - Proximity analysis combining all location types

---

### Step 7: View the Data Lineage

1. In your workspace, click on the **"DAG"** tab (next to Query History)
2. You'll see a visual representation of your data lineage:

![Silver Layer DAG](images/5_silver_dag.png)

**Understanding the DAG:**

- **Left side (Source tables)**: Raw data from the private listing
  - `taxi_availability`
  - `tourist_attractions`
  - `hawker_centres`
  - `lta_mrt_station_exit`
  - `weather_forecast_2h`

- **Middle (Silver models)**: Your cleaned and structured tables
- **Right side (Gold models)**: Business logic and analytics

**Key Features:**
- 🔄 **Simplified refresh**: Latest data snapshots only
- 📊 **Data quality**: All models have tests ensuring data integrity
- 🗺️ **Spatial data**: All location models use Snowflake's native GEOGRAPHY type
- 🎯 **Unique identifiers**: Proper IDs for each location type

---

## 🛠️ Troubleshooting

### Issue: "Invalid profile: 'user' is a required property"

**Solution:** This is expected! dbt Workspaces runs under your current user context, so `user` and `account` can be left empty in `profiles.yml`.

---

### Issue: Dynamic Table not refreshing

**Solution:**
1. Check the warehouse is running: `SHOW WAREHOUSES LIKE 'TECHUP25_WH';`
2. Verify target_lag setting in `dbt_project.yml`
3. Manually refresh: `ALTER DYNAMIC TABLE <table_name> REFRESH;`

---

### Issue: "Configuration paths exist which do not apply to any resources"

**Cause:** You have `gold` configuration but no models in the gold folder yet.

**Solution:** Either:
1. Create gold models, or
2. Comment out the gold section in `dbt_project.yml` temporarily

---

### Issue: Git integration not working

**Solution:**
1. Verify API integration is created: `SHOW API INTEGRATIONS;`
2. Check the allowed prefixes match your Git URL
3. Ensure repository is public (or configure Personal Access Token)

---

### Issue: Source tables not found

**Solution:**
1. Verify you have access to the private listing: `SHOW DATABASES LIKE 'APJ_TECHUP_FY26%';`
2. Check the database and schema names in `models/_sources.yml`
3. Grant necessary privileges: `GRANT USAGE ON DATABASE APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET TO ROLE TECHUP25_RL;`

---

### Issue: Geography GROUP BY errors

**Solution:** 
This has been resolved in the current models by:
1. Using `ANY_VALUE()` for geography fields in aggregations
2. Separating spatial calculations from GROUP BY operations
3. Using proper CTE structure to avoid geography in grouping

---

## 🎓 Setup Complete!

You've successfully set up:
✅ Snowflake environment with proper roles and permissions  
✅ dbt Workspace connected to Git  
✅ Silver layer models with latest data extraction  
✅ Gold layer models with spatial analytics  
✅ Data quality tests and validation  
✅ Visual data lineage  

**Next Steps:** Return to the main [README.md](README.md) to explore the project architecture and key concepts.
