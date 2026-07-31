SELECT 
        *
    FROM {{ source('bronze', 'raw_clients')  }}