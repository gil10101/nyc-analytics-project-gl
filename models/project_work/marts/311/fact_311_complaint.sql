-- Fact table for 311 complaints
-- One row per complaint, joined to dimension keys

WITH complaints AS (
   SELECT * FROM {{ ref('stg_311') }}
),

fact_complaint AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['c.request_id']) }} AS complaint_key,

       -- Foreign keys to dimensions
       {{ dbt_utils.generate_surrogate_key(['CAST(c.created_date AS DATE)']) }} AS created_date_key,
       {{ dbt_utils.generate_surrogate_key(['CAST(c.closed_date AS DATE)']) }} AS closed_date_key,
       {{ dbt_utils.generate_surrogate_key(['c.bbl']) }} AS location_key,
       {{ dbt_utils.generate_surrogate_key(['c.complaint_type', 'c.location_type']) }} AS complaint_type_key,

       -- Degenerate dimension - keep raw 311 ID for traceability
       CAST(c.request_id AS INT64) AS unique_key,

       -- Measures
       1 AS complaint_count,
       CAST(c.days_to_close AS INT64) AS days_to_close

   FROM complaints c
)

SELECT * FROM fact_complaint