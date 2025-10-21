select 
    ta.DATA:features[0]:properties:timestamp::timestamp as timestamp_sgt 
    , ta.DATA:features[0]:properties:taxi_count::bigint as taxi_count
    , ta.DATA:features[0]:properties:api_info:status::varchar as api_status
from {{ source('raw_data', 'taxi_availability') }} ta