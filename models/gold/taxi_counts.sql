select 
    timestamp_sgt
    , taxi_count
from {{ ref('taxi_availability_metadata') }}