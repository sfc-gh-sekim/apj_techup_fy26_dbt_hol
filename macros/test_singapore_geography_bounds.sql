-- Custom test macro to validate that GEOGRAPHY points are within Singapore bounding box
-- Singapore bounds: lat 1.1304753 to 1.4504753, lng 103.6920359 to 104.0120359

{% test singapore_geography_bounds(model, column_name) %}

    with validation as (
        select 
            {{ column_name }} as geography_point,
            st_x({{ column_name }}) as longitude,
            st_y({{ column_name }}) as latitude,
            case 
                when st_x({{ column_name }}) between 103.6920359 and 104.0120359 
                 and st_y({{ column_name }}) between 1.1304753 and 1.4504753 
                then 1 
                else 0 
            end as is_within_singapore_bounds
        from {{ model }}
        where {{ column_name }} is not null
    )

    select 
        geography_point,
        longitude,
        latitude,
        'Point (' || longitude || ', ' || latitude || ') is outside Singapore bounds' as error_message
    from validation 
    where is_within_singapore_bounds = 0

{% endtest %}
