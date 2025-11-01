# Hands-On Lab - Singapore Taxi Availability Data Transformation Pipeline

This guide walks you through setting up the dbt project on Snowflake Workspaces to transform Singapore transportation and location data.

By the end of this HOL you should walk away with:

- Knowledge of fundamental dbt concepts
- How dbt executes transformation scripts in Snowflake 
- How your customers can develop and deploy dbt projects via Workspaces
- Understand materialisations

---

## Step 1: Get Dataset from Private Listing

This is a **private listing** shared specifically for this lab. The data is continuously updated from Singapore's data.gov.sg APIs. New data arrives at least once a minute.

1. Navigate to **Horizon Catalog** → **Data sharing** → **Private Sharing** in Snowsight
2. Search for **"APJ TechUP FY26 - Singapore Taxi Dataset"**
3. Click on the listing
5. Click **Get**

> **_Note:_** You may get a "Getting Data Ready - This will take at least 10 minutes" message here. Congratulations, you are the first account in your region to get this share! Replication usually won't take that long, but for now skip this step and proceed. Come back to this step before Step 6 at the latest.

5. Leave the Database name as the default, this should be `APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET`

![Private Listing](images/1_marketplace.png)

6. Verify you can see these tables under `APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET.RAW_DATA`:
   - `HAWKER_CENTRES`
   - `LTA_MRT_STATION_EXIT`
   - `TAXI_AVAILABILITY`
   - `TOURIST_ATTRACTIONS`

---

## Step 2: Set up your Snowflake Environment

1. Open a **SQL Worksheet** in Snowsight
2. Copy the contents of [`setup.sql`](setup.sql)
3. Run the entire script

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

## Step 3: Create Workspace from Git

1. In Snowsight, navigate to **Projects** → **Workspaces**
2. Create a new Workspace - Under the workspaces dropdown (top-left of Workspaces UI), under the `Create Workspace` section, click **"From Git Repository"**
3. Fill in the details:

   | Field | Value |
   |-------|-------|
   | **Repository URL** | `https://github.com/sfc-gh-sekim/apj_techup_fy26_dbt_hol` |
   | **Workspace name** | `apj_techup_fy26_dbt_hol` |
   | **API Integration** | `TECHUP_DBT_HOL_API_INTEGRATION` |
   | **Authentication** | Public repository (no PAT needed) |

4. Click **"Create"**

![Create Workspace](images/2_setup.png)

5. Wait for the workspace to initialize (should take ~30 seconds)
6. You should see the project files load in the left sidebar

---

## Step 4: Understand your dbt project

Now that you have the workspace set up, let's take a tour of the key components that make up this dbt project. Understanding these files will help you navigate and modify the project effectively.

### 📄 dbt_project.yml - Project Configuration

The [`dbt_project.yml`](dbt_project.yml) file is the heart of your dbt project. It defines project-level configurations and tells dbt how to operate on your models.

```yml
name: 'techup_dbt_hands_on_lab'
version: '1.0.0'

profile: 'techup_dbt_hands_on_lab'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

clean-targets:       
  - "target"
  - "dbt_packages"

models:
  techup_dbt_hands_on_lab:
    silver:
      +materialized: table
      +schema: DBT_HOL_SILVER
    gold:
      +materialized: table
      +schema: DBT_HOL_GOLD
```

**Key Components:**
- **name**: Unique identifier for your dbt project
- **profile**: References the connection profile in [`profiles.yml`](profiles.yml)
- **Directory paths**: Tell dbt where to find models, tests, macros, etc.
- **models configuration**: Sets default materialization (`table`) and custom schemas for silver and gold layers

### 🔌 profiles.yml - Connection Configuration

The [`profiles.yml`](profiles.yml) file contains connection details for your Snowflake environment. In a real production environment, it's common for multiple profiles to be defined here in order for CI/CD pipelines to correctly deploy models to the right environment.

```yml
techup_dbt_hands_on_lab:
  target: prod
  outputs:
    prod:
      type: snowflake
      role: TECHUP25_RL
      warehouse: TECHUP25_WH
      database: TECHUP25
      schema: PUBLIC
      account: ''
      user: ''
```

- Snowflake will automatically runs under the current account and user context. dbt still expects `account` and `user` fields to be specified; we will leave these as empty strings as placeholders 
- The `target: prod` setting determines which output configuration is used by default

### 📊 Model Files and Macros

**Model Files** contain the SQL transformations that define your data pipeline. They use Jinja templating for dynamic SQL generation.

**Example - Silver Layer Model:**
```sql
select 
    ta.DATA:features[0]:properties:timestamp::timestamp as timestamp_sgt
    , st_makepoint(f.value[0], f.value[1]) as taxi_coords
from {{ source('raw_data', 'taxi_availability') }} ta
    , lateral flatten(input => ta.DATA:features[0]:geometry:coordinates) f
```

**Key Features:**
- **Jinja templating**: `{{ source() }}` dynamically references source tables
- **Semi-structured data processing**: Extracts data from JSON/GeoJSON using Snowflake's VARIANT functions
- **Geospatial functions**: `ST_MAKEPOINT()` creates geography objects for spatial analysis

**Macros** are reusable pieces of Jinja code that generate SQL. This project includes a custom schema macro:

```sql
-- Overrides default dbt behaviour on schema handling. See https://docs.getdbt.com/docs/build/custom-schemas#a-built-in-alternative-pattern-for-generating-schema-names
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ generate_schema_name_for_env(custom_schema_name, node) }}
{%- endmacro %}
```

This macro customizes how dbt generates schema names, ensuring models land in the correct schemas (e.g., `DBT_HOL_SILVER`, `DBT_HOL_GOLD`).

### 📋 Schema YAML Files - Documentation and Testing

Schema YAML files (like `_schema.yml` and `_sources.yml`) serve two critical purposes: **documentation** and **data quality testing**.

**Source Configuration** (`models/_sources.yml`):
```yml
sources:
  - name: raw_data
    description: "Landing tables for raw data from data.gov.sg APIs"
    database: APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET
    schema: RAW_DATA
    tables:
      - name: taxi_availability
        description: "Real-time taxi availability data from Singapore's LTA Datamall, retrieved every minute"
        meta:
          data_source: "data.gov.sg Transport API"
          update_frequency: "Every 1 minute"
          data_format: "GeoJSON"
          api_endpoint: "https://api.data.gov.sg/v1/transport/taxi-availability"
        columns:
          - name: dataset_id
            description: "Identifier for the dataset source"
            data_type: varchar(100)
          - name: retrieved_at
            description: "Timestamp when the data was retrieved from the API"
            data_type: timestamp_ntz
          - name: data
            description: "Raw GeoJSON data containing taxi locations and metadata"
            data_type: variant
            meta:
              contains:
                - "type: GeoJSON type (FeatureCollection)"
                - "features: Array of taxi location features with coordinates"
                - "properties: Metadata including timestamp and taxi count"
          - name: created_at
            description: "Timestamp when the record was inserted into Snowflake"
            data_type: timestamp_ntz
```

**Model Documentation and Testing** (`models/silver/_schema.yml`):
```yml
models:
  - name: hawker_centres
    description: "Cleaned and structured hawker centre data with extracted location and facility information"
    meta:
      layer: "silver"
      data_source: "Singapore data.gov.sg hawker centres dataset"
      dataset_url: "https://data.gov.sg/datasets/d_4a086da0a5553be1d89383cd90d07ecd/view"
      transformation: "Flattened GeoJSON features with parsed properties"
    columns:
      - name: objectid
        description: "Unique object identifier for the hawker centre"
        data_type: varchar
        tests:
          - not_null
      - name: name
        description: "Name of the hawker centre"
        data_type: varchar
        tests:
          - not_null
      - name: address
        description: "Full address of the hawker centre"
        data_type: varchar
      - name: street_name
        description: "Street name component of the address"
        data_type: varchar
      - name: postcode
        description: "Postal code of the hawker centre"
        data_type: varchar
      - name: num_cooked_food_stalls
        description: "Number of cooked food stalls in the hawker centre"
        data_type: int
        tests:
          - not_null
      - name: photo_url
        description: "URL to photo of the hawker centre"
        data_type: varchar
      - name: coords
        description: "Geographic coordinates as Snowflake GEOGRAPHY point"
        data_type: geography
        tests:
          - not_null
          - singapore_geography_bounds:
              config:
                severity: warn
      - name: data
        description: "Original raw JSON data for reference"
        data_type: variant
```

**Key Benefits of Schema YAML Files:**
- **Documentation**: Descriptions, metadata, and data lineage information
- **Data Quality Testing**: Built-in tests, for example: `not_null`, `unique`, `accepted_values`
- **Custom Tests**: Project includes [`singapore_geography_bounds`](macros/test_singapore_geography_bounds.sql) test for spatial data validation
- **Data Catalog Integration**: Automatically generates documentation in dbt's web interface
- **Version Control**: Documentation stays in sync with code changes

**Test Types Available:**
- **Generic tests**: `not_null`, `unique`, `accepted_values`, `relationships`
- **Custom tests**: Like `singapore_geography_bounds` defined in `macros/test_singapore_geography_bounds.sql`
- **Severity levels**: `warn` vs `error` to control pipeline behavior

### ❓ Other Features Not Covered in this HOL
Consider the above as a crash course on core dbt features - our customers often leverage other capabilities included in dbt Core. Feel free to read about these in your own time:

- [Snapshots](https://docs.getdbt.com/docs/build/snapshots): Records changes to a table over time with SCD2
- [Seeds](https://docs.getdbt.com/docs/build/seeds): Load static data defined as CSV files in the `seeds/` folder
- [User-defined functions](https://docs.getdbt.com/docs/build/udfs): Define UDFs
- [Exposures](https://docs.getdbt.com/docs/build/exposures): Documentation that describes downstream use of the dbt project
- [Groups](https://docs.getdbt.com/docs/build/groups): Document a collection of nodes within a dbt DAG
- [Docs](https://docs.getdbt.com/reference/commands/cmd-docs): Generate a static website compiled from the dbt project
- [Analyses](https://docs.getdbt.com/docs/build/analyses): Allow analysts to version control analytical queries related to the project

---

## Step 5: Compile the dbt Project

We will first "compile" the dbt project. This generates executable SQL contained in the `model`, `tests` and `analysis` folders *without* executing those queries in Snowflake. This allows developers to visually inspect fully resolved models, validate jinja / macro usage and manually running queries for debugging or development purposes.

1. In your workspace, ensure **Profile** is set to to `prod`
2. To the right, select `Compile` from the list of dbt operations
3. Click the **Run** ▶️ button

This will run for a few seconds. Once complete, you will notice a new folder created in your workspace: `target/compiled/techup_dbt_hands_on_lab`. 

Feel free to explore the various SQL scripts that have been generated - the below is a simple example of what was performed with this command:

### 🔍 Example Transformation: taxi_availability.sql

This model flattens and transforms raw GeoJSON taxi data into a flat table.

Note the contents of the `models/silver/taxi_availability.sql` model file:

```sql
--models/silver/taxi_availability.sql
select 
    ta.DATA:features[0]:properties:timestamp::timestamp as timestamp_sgt
    , st_makepoint(f.value[0], f.value[1]) as taxi_coords
from {{ source('raw_data', 'taxi_availability') }} ta -- Note the jinja template here
    , lateral flatten(input => ta.DATA:features[0]:geometry:coordinates) f
qualify rank() over (order by retrieved_at desc) = 1
```

In the compiled version `target/compiled/techup_dbt_hands_on_lab/silver/taxi_availability.sql`, dbt dynamically generates the SQL from the jinja template - in this specific template the `source()` call looks up the corresponding source table reference in `models/_sources.yml`:

```yml
# models/_sources.yml

sources:
  - name: raw_data
    description: "Landing tables for raw data from data.gov.sg APIs"
    database: APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET
    schema: RAW_DATA
    tables:
      - name: taxi_availability
        description: "Real-time taxi availability data from Singapore's LTA Datamall, retrieved every minute"
```

Resulting compiled SQL:

```sql
--target/compiled/techup_dbt_hands_on_lab/silver/taxi_availability.sql
select 
    ta.DATA:features[0]:properties:timestamp::timestamp as timestamp_sgt
    , st_makepoint(f.value[0], f.value[1]) as taxi_coords
from APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET.RAW_DATA.taxi_availability ta
    , lateral flatten(input => ta.DATA:features[0]:geometry:coordinates) f
```

You can meta-program any arbitrary SQL with jinja, and dbt provides a [wide range of functions](https://docs.getdbt.com/reference/dbt-jinja-functions), including standard functions available from the Python jinja library.

As a developer, you can manually validate queries by running it directly on Snowflake. As we are working in Snowflake Workspaces, this is a simply a matter of hitting the run query button as this is no different to any other worksheet you run in Workspaces.

---

## Step 6: Run the dbt Project

We will first run silver layer dbt models. 

1. In your workspace, set the **Profile** to `silver` (top right dropdown)
2. Click the dropdown next to the **Run** button
3. Untick `Execute with defaults`
4. In the `Additional flags` textbox, enter `--select silver.*`. This specifies only the models in the `models/silver/` folder to be run

![Run dbt Project](images/4_run_silver.png)

4. Click **Execute**

**What Happens:**

The dbt engine will:
1. ✅ Parse your dbt project (`dbt_project.yml`)
2. ✅ Compile SQL models with Jinja templates
3. ✅ Run data quality tests (these are defined in `_schema.yml`)
4. ✅ Create **6 Tables** in `TECHUP25.DBT_HOL_SILVER`:
   - `hawker_centres`
   - `mrt_station_exits`
   - `taxi_availability`
   - `taxi_availability_metadata`
   - `tourist_attractions`
   - `all_locations`

5. ✅ Display execution results with timing

**Expected Output:**
```
03:23:55.311707 [info ] [Dummy-1   ]: Running with dbt=1.9.4
03:23:55.391529 [error] [Dummy-1   ]:  adapter: Invalid profile: 'user' is a required property.
03:23:55.723377 [info ] [Dummy-1   ]: Registered adapter: snowflake=1.9.2
03:23:57.753088 [info ] [Dummy-1   ]: Found 9 models, 47 data tests, 4 sources, 592 macros
03:23:57.757472 [info ] [Dummy-1   ]: 
03:23:57.758310 [info ] [Dummy-1   ]: Concurrency: 1 threads (target='prod')
03:23:57.758990 [info ] [Dummy-1   ]: 
03:23:59.570553 [info ] [Thread-2 (]: 1 of 6 START sql table model DBT_HOL_SILVER.hawker_centres ..................... [RUN]
03:24:00.816014 [info ] [Thread-2 (]: 1 of 6 OK created sql table model DBT_HOL_SILVER.hawker_centres ................ [SUCCESS 1 in 1.24s]

...

03:24:14.288308 [info ] [Thread-2 (]: 6 of 6 START sql table model DBT_HOL_SILVER.all_locations ...................... [RUN]
03:24:15.460188 [info ] [Thread-2 (]: 6 of 6 OK created sql table model DBT_HOL_SILVER.all_locations ................. [SUCCESS 1 in 1.17s]
03:24:15.468700 [info ] [Dummy-1   ]: 
03:24:15.469483 [info ] [Dummy-1   ]: Finished running 6 table models in 0 hours 0 minutes and 17.71 seconds (17.71s).
03:24:15.537683 [info ] [Dummy-1   ]: 
03:24:15.538506 [info ] [Dummy-1   ]: Completed successfully
03:24:15.539200 [info ] [Dummy-1   ]: 
03:24:15.541030 [info ] [Dummy-1   ]: Done. PASS=6 WARN=0 ERROR=0 SKIP=0 TOTAL=6
```

You should now be able to see tables in the `TECHUP25.DBT_HOL_SILVER` schema. We will now proceed with the gold layer.

---

## Step 7: Run the Gold Layer

1. Click the dropdown next to the **Run** button
2. Untick `Execute with defaults`
3. In the `Additional flags` textbox, enter `--select gold.*`
4. Click the **Run** ▶️ button

This will create the **Gold Layer** models in `TECHUP25.DBT_HOL_GOLD`.

---

## Step 8: View the Data Lineage

1. In your workspace, click on the **"DAG"** tab (next to Query History)
2. You'll see a visual representation of your data lineage:

![Silver Layer DAG](images/5_dag.png)

3. Click on any of the models to open up the corresponding worksheet, as well as additional information about the model.

---

## Step 9: Run data tests

1. In your workspace, under the dbt command dropdown, select `Test`
2. This time, we'll run tests on the entire project - click the **Run** ▶️ button


> **_NOTE:_** dbt also handily provides a `build` command - you may have already noticed this in the command dropdown. This will run models and tests under a single command, as well as other functions such as snapshots, seeds and UDFs, which we do not cover in this HOL. This is often run as a part of an automated refresh if the customer would prefer to run the entire end-to-end process without having to run multiple calls.

---

## Step 10: Run as Dynamic Tables

Up until this point, all dbt models have been materialised as tables. In order to keep the silver and gold models fresh with new records arriving in the data share, a task needs to be run every minute; while this is well within Snowflake's capabilities, the overhead cost of running dbt in addition to any processing times will likely become a nuisance as the project scales out.

As an alternative to frequent task runs, we will leverage the `dbt-snowflake` adapter's support for Dynamic Tables to convert our existing models to them. This will delegate the data refresh orchestration to Snowflake, while dbt runs handle any configuration / model changes, as well as any tests that can now be scheduled independently of data refreshes.

This can be configured at one of three locations in a dbt project:

1. Within the `dbt_project.yml` file
2. Within the schema definition in `models/*/*.yml` files
3. Within the model files

A discussion of the intricacies of mixing different materialisation types in a dbt project is out of scope for this HOL - but in general exercise caution in mixing DTs and regular Tables as this can often lead to some interesting results! We will avoid this challenge altogether by converting *all* tables to DTs so that all refresh logic is delegated to Snowflake. To do this, we can set this within the `dbt_project.yml` file.

Replace the entire `models` block within the `dbt_project.yml` file with the following:

```yml
models:
  techup_dbt_hands_on_lab:
    silver:
      +materialized: dynamic_table
      +schema: DBT_HOL_SILVER
      +snowflake_warehouse: TECHUP25_WH
      +on_configuration_change: apply
      +target_lag: downstream
      +refresh_mode: INCREMENTAL
      +initialize: ON_CREATE
    gold:
      +materialized: dynamic_table
      +schema: DBT_HOL_GOLD
      +snowflake_warehouse: TECHUP25_WH
      +on_configuration_change: apply 
      +target_lag: '24 HOURS'
      +refresh_mode: INCREMENTAL
      +initialize: ON_CREATE
```

This will create silver layer DTs with `target_lag` set to `DOWNSTREAM`, and gold DTs with a default `target_lag` of 24 hours. This is sufficient for location-level datasets that update infrequently, but any models relying on the `taxi_availability` source table will require a far lower lag value. We will override the `target_lag` value at the file level for those models specifically.

In the `models/gold/taxi_counts.sql` model file, add an extra configuration block at the top of the file:

```sql
--models/gold/taxi_counts.sql
{{ config(target_lag = '1 MINUTE') }}

select 
    timestamp_sgt
    , taxi_count
from {{ ref('taxi_availability_metadata') }}
```

Repeat for `models/gold/taxi_counts_by_location.sql`. 

Now run the dbt project:

1. From the dbt command dropdown, select `Build`
2. Click the **Run** ▶️ button

This should overwrite your existing models to DTs.

---

## Step 11: Deploy dbt Project

If you have been paying attention to the dbt execution logs, the dbt project has been stored and run from your user database (i.e. `USER$<your_user_name>`). To deploy it as a DBT PROJECT object within the database that can be monitored across the account:

1. On the top-right side of the Workspaces UI, click **"Connect"**
2. Click **"Deploy dbt project"**
3. Fill in the details:

   | Field | Value |
   |-------|-------|
   | **Select location** | Database: `TECHUP` Schema: `PROJECTS` |
   | **Select or create dbt project** | `apj_techup_fy26_dbt_hol` |
   | **Enter Name** | `TECHUP_DBT_PROJECT` |
   | **Description** | `TechUP FY26 Singapore Taxi DBT project` |
   | **Default Target** | `prod` |
   | **Run dbt deps** | Unticked |

4. Click "Deploy"

---
## 🎓 HOL Complete!

If you've finished this in good time and you're bored, try writing your own models! The `models/*/_schema.yml` files make for some great context for Cursor :-)
