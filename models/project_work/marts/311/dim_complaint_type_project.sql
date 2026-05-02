-- Complaint type dimension
-- One row per unique combination of complaint_type and location_type

WITH complaint_types AS (
   SELECT DISTINCT
       complaint_type,
       location_type
   FROM {{ ref('stg_311') }}
   WHERE complaint_type IS NOT NULL
),

complaint_type_dimension AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['complaint_type', 'location_type']) }} AS complaint_type_key,

       CAST(complaint_type AS STRING) AS complaint_type,
       CAST(location_type AS STRING) AS location_type

   FROM complaint_types
)

SELECT * FROM complaint_type_dimension