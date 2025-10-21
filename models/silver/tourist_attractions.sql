SELECT 
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>URL_PATH</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) AS url_path,
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>ADDRESS</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) AS address,
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>PAGETITLE</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) AS page_title,
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>IMAGE_PATH</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) AS image_path,
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>PHOTOCREDITS</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) AS photo_credits,
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>OVERVIEW</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) AS overview,
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>EXTERNAL_LINK</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) AS external_link,
    REGEXP_SUBSTR(f.value:properties:Description::varchar, '<th>OPENING_HOURS</th>\\s*<td>([^<]+)</td>', 1, 1, 'e', 1) AS opening_hours,
    st_makepoint(f.value:geometry:coordinates[0], f.value:geometry:coordinates[1]) as coords,
    f.value:properties:Description::varchar as raw_description_html
from {{ source('raw_data', 'tourist_attractions') }} ta,
lateral flatten(input => ta.DATA:features) f
qualify rank() over (order by retrieved_at desc) = 1