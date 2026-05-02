-- Fact table for buildings (built / altered)
-- One row per BBL, with foreign keys to location, building, and age category dimensions

WITH pluto AS (
   SELECT * FROM {{ ref('stg_pluto') }}
),

fact_building AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['p.bbl']) }} AS building_fact_key,

       -- Foreign keys to dimensions
       {{ dbt_utils.generate_surrogate_key(['p.bbl']) }} AS location_key,
       {{ dbt_utils.generate_surrogate_key(['p.bbl']) }} AS building_key,
       {{ dbt_utils.generate_surrogate_key(['p.building_age_category']) }} AS age_category_key,

       -- Year measures
       CAST(p.year_built AS INT64) AS year_built,
       CAST(p.year_alter1 AS INT64) AS yearalter1,
       CAST(p.year_alter2 AS INT64) AS yearalter2

   FROM pluto p
   WHERE p.bbl IS NOT NULL
)

SELECT * FROM fact_building