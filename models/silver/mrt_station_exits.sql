select 
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>STATION_NA</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) as station_name,
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>EXIT_CODE</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) as exit_code,
    st_makepoint(f.value:geometry:coordinates[0], f.value:geometry:coordinates[1]) as coords,
    f.value:properties:Description::varchar as raw_description_html
from {{ source('raw_data', 'lta_mrt_station_exit') }} mrt,
lateral flatten(input => mrt.DATA:features) f;