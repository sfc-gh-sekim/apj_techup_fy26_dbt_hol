with tourist_attractions as (
    select 
        location_id,
        location_name,
        location_type,
        address,
        street_name,
        postcode,
        photo_url,
        location_coords,
        location_description
    from {{ ref('all_locations') }}
    where location_type = 'tourist_attraction'
),
mrt_stations as (
    select 
        location_id,
        location_name,
        location_coords,
        location_description
    from {{ ref('all_locations') }}
    where location_type = 'mrt_station_exit'
),
hawker_centres as (
    select 
        location_id,
        location_name,
        location_coords,
        location_description,
        address
    from {{ ref('all_locations') }}
    where location_type = 'hawker_centre'
),
-- Find nearest MRT station for each tourist attraction
nearest_mrt as (
    select 
        ta.location_id as tourist_location_id,
        mrt.location_id as nearest_mrt_location_id,
        mrt.location_name as nearest_mrt_name,
        mrt.location_description as nearest_mrt_description,
        st_distance(ta.location_coords, mrt.location_coords) as distance_to_nearest_mrt_m,
        row_number() over (
            partition by ta.location_id 
            order by st_distance(ta.location_coords, mrt.location_coords)
        ) as rn
    from tourist_attractions ta
    cross join mrt_stations mrt
),
-- Find nearest hawker centre for each tourist attraction
nearest_hawker as (
    select 
        ta.location_id as tourist_location_id,
        hc.location_id as nearest_hawker_location_id,
        hc.location_name as nearest_hawker_name,
        hc.location_description as nearest_hawker_description,
        hc.address as nearest_hawker_address,
        st_distance(ta.location_coords, hc.location_coords) as distance_to_nearest_hawker_m,
        row_number() over (
            partition by ta.location_id 
            order by st_distance(ta.location_coords, hc.location_coords)
        ) as rn
    from tourist_attractions ta
    cross join hawker_centres hc
)
-- Final result combining all information
select 
    ta.location_id,
    ta.location_name,
    ta.location_type,
    ta.address,
    ta.street_name,
    ta.postcode,
    ta.photo_url,
    ta.location_coords,
    ta.location_description,

    -- Nearest MRT station information
    nm.nearest_mrt_location_id,
    nm.nearest_mrt_name,
    nm.nearest_mrt_description,
    nm.distance_to_nearest_mrt_m,
    round(nm.distance_to_nearest_mrt_m, 0) as distance_to_nearest_mrt_m_rounded,
    
    -- Nearest hawker centre information
    nh.nearest_hawker_location_id,
    nh.nearest_hawker_name,
    nh.nearest_hawker_description,
    nh.nearest_hawker_address,
    nh.distance_to_nearest_hawker_m,
    round(nh.distance_to_nearest_hawker_m, 0) as distance_to_nearest_hawker_m_rounded,
    
    -- Proximity categories using reusable macro
    {{ categorize_distance('nm.distance_to_nearest_mrt_m', [500, 1000, 2000]) }} as mrt_proximity_category,
    {{ categorize_distance('nh.distance_to_nearest_hawker_m', [300, 800, 1500]) }} as hawker_proximity_category

from tourist_attractions ta
left join nearest_mrt nm 
    on ta.location_id = nm.tourist_location_id 
    and nm.rn = 1
left join nearest_hawker nh 
    on ta.location_id = nh.tourist_location_id 
    and nh.rn = 1
