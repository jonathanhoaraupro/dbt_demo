SELECT 
        *
    FROM {{ source('bronzee', 'raw_clients') }}