-- Custom test macro to validate that GEOGRAPHY points are within Singapore bounding box
-- Singapore bounds: lat 1.13 to 1.47, lng 103.59 to 104.07

{% test singapore_geography_bounds(model, column_name) %}

    with validation as (
        select 
            {{ column_name }} as geography_point,
            st_x({{ column_name }}) as longitude,
            st_y({{ column_name }}) as latitude,
            case 
                when st_x({{ column_name }}) between 103.59 and 104.07
                 and st_y({{ column_name }}) between 1.13 and 1.47
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
