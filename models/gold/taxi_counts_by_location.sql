-- Gold layer model: Historical taxi counts by location with proximity analysis
-- Uses temporal ASOF join to match taxi availability data with location timestamps
-- Calculates taxi availability within 100m, 500m, and 1km radius over time

with taxi_proximity_calculations as (
    select 
        l.timestamp_sgt as location_timestamp_sgt,
        l.location_id,
        l.location_name,
        l.location_type,
        l.address,
        l.location_description,
        l.location_coords,
        t.timestamp_sgt as taxi_timestamp_sgt,
        t.timestamp as taxi_data_timestamp,
        -- Calculate distances and count taxis within each radius
        count(case 
            when st_dwithin(l.location_coords, t.taxi_coords, 100) 
            then 1 
        end) as taxis_within_100m,
        count(case 
            when st_dwithin(l.location_coords, t.taxi_coords, 500) 
            then 1 
        end) as taxis_within_500m,
        count(case 
            when st_dwithin(l.location_coords, t.taxi_coords, 1000) 
            then 1 
        end) as taxis_within_1km,
        -- Additional metrics for analysis
        min(case 
            when t.taxi_coords is not null 
            then st_distance(l.location_coords, t.taxi_coords)
        end) as distance_to_nearest_taxi_m,
        count(t.taxi_coords) as total_taxis_in_dataset
    from {{ ref('all_locations') }} l
    asof join {{ ref('taxi_availability') }} t
        match_condition (l.timestamp_sgt >= t.timestamp_sgt)
        on l.location_id = l.location_id  -- Self-join condition for ASOF syntax
    group by 
        l.timestamp_sgt,
        l.location_id,
        l.location_name,
        l.location_type,
        l.address,
        l.location_description,
        l.location_coords,
        t.timestamp_sgt,
        t.timestamp
)
select 
    location_timestamp_sgt,
    taxi_timestamp_sgt,
    location_id,
    location_name,
    location_type,
    address,
    location_description,
    location_coords,
    taxi_data_timestamp,
    taxis_within_100m,
    taxis_within_500m,
    taxis_within_1km,
    distance_to_nearest_taxi_m,
    case 
        when taxis_within_100m > 0 then 'High'
        when taxis_within_500m > 0 then 'Medium'
        when taxis_within_1km > 0 then 'Low'
        else 'None'
    end as taxi_availability_category,
    -- Percentage of total taxis within each radius
    round((taxis_within_100m::float / nullif(total_taxis_in_dataset, 0)) * 100, 2) as pct_taxis_within_100m,
    round((taxis_within_500m::float / nullif(total_taxis_in_dataset, 0)) * 100, 2) as pct_taxis_within_500m,
    round((taxis_within_1km::float / nullif(total_taxis_in_dataset, 0)) * 100, 2) as pct_taxis_within_1km,
    total_taxis_in_dataset
from taxi_proximity_calculations
order by 
    location_timestamp_sgt desc,
    taxi_timestamp_sgt desc,
    location_type,
    taxis_within_100m desc,
    location_name