use role accountadmin;
use database techup25;
use schema dbt_hol_silver;

select max(retrieved_at) from APJ_TECHUP_FY26__SINGAPORE_TAXI_DATASET.RAW_DATA.TOURIST_ATTRACTIONS;