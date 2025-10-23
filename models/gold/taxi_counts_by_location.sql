with latest_taxi_data as (
    select 
        timestamp_sgt
        , taxi_coords
    from {{ ref('taxi_availability') }}
    -- Take last hour only
    --where timestamp_sgt >= (select dateadd(hours, -1, max(timestamp_sgt)) from {{ ref('taxi_availability') }})
)
, location_taxi_pairs as (
    -- Create all location-taxi pairs with distances using latest data
    select 
        l.location_id
        , l.location_name
        , l.location_type
        , l.address
        , l.location_description
        , l.location_coords
        , t.timestamp_sgt
        , t.taxi_coords
        , st_distance(l.location_coords, t.taxi_coords) as distance_m
        , case when st_dwithin(l.location_coords, t.taxi_coords, 100) then 1 else 0 end as within_100m
        , case when st_dwithin(l.location_coords, t.taxi_coords, 500) then 1 else 0 end as within_500m
        , case when st_dwithin(l.location_coords, t.taxi_coords, 1000) then 1 else 0 end as within_1km
    from {{ ref('all_locations') }} l
    cross join latest_taxi_data t
)
, taxi_proximity_calculations as (
    -- Aggregate proximity metrics for each location
    select 
        location_id
        , location_name
        , location_type
        , address
        , location_description
        , any_value(location_coords) as location_coords
        , any_value(timestamp_sgt) as timestamp_sgt
        , sum(within_100m) as taxis_within_100m
        , sum(within_500m) as taxis_within_500m
        , sum(within_1km) as taxis_within_1km
        , min(distance_m) as distance_to_nearest_taxi_m
        , count(taxi_coords) as total_taxis_in_dataset
    from location_taxi_pairs
    group by 
        location_id
        , location_name
        , location_type
        , address
        , location_description
)
select
    timestamp_sgt
    , location_id
    , location_name
    , location_type
    , address
    , location_description
    , location_coords
    , taxis_within_100m
    , taxis_within_500m
    , taxis_within_1km
    , distance_to_nearest_taxi_m
    , total_taxis_in_dataset
from taxi_proximity_calculations
order by 
    location_type
    , taxis_within_100m desc
    , location_name