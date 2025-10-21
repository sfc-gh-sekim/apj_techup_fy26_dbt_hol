select 
    dateadd(hour, 8, retrieved_at) as timestamp_sgt
    , ta.DATA:features[0]:properties:timestamp::timestamp as timestamp
    , st_makepoint(f.value[0], f.value[1]) as taxi_coords
from {{ source('raw_data', 'taxi_availability') }} ta,
lateral flatten(input => ta.DATA:features[0]:geometry:coordinates) f