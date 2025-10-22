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