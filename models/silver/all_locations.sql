-- Hawker Centres
select 
    'HC_' || md5(name) as location_id
    , name as location_name
    , 'hawker_centre' as location_type
    , address
    , street_name
    , postcode
    , photo_url
    , coords as location_coords
    , 'Singapore hawker centre with ' || coalesce(num_cooked_food_stalls, 0) || ' food stalls' as location_description
from {{ ref('hawker_centres') }}

union all

-- MRT Station Exits
select 
    'MRT_' || md5('MRT station exit: ' || exit_code || ' at ' || station_name) as location_id
    , station_name as location_name
    , 'mrt_station_exit' as location_type
    , null as address
    , null as street_name
    , null as postcode
    , null as photo_url
    , coords as location_coords
    , 'MRT station exit: ' || exit_code || ' at ' || station_name as location_description
from {{ ref('mrt_station_exits') }}

union all

-- Tourist Attractions
select 
    'TA_' || md5(replace(replace(page_title, ' ', '_'), '''', '')) as location_id
    , page_title as location_name
    , 'tourist_attraction' as location_type
    , address
    , null as street_name
    , null as postcode
    , image_path as photo_url
    , coords as location_coords
    , coalesce(overview, 'Tourist attraction in Singapore') as location_description
from {{ ref('tourist_attractions') }}
where page_title is not null
