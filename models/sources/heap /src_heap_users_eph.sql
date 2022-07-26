SELECT *
FROM {{ source('heap','users') }} u 
WHERE u."identity" <> 'null'