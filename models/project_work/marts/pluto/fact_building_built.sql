-- Fact table for buildings (built / altered)
-- One row per BBL, with foreign keys to location, building, and age category dimensions

WITH pluto AS (
   SELECT * FROM {{ ref('stg_pluto') }}
),

age_categories AS (
   SELECT * FROM {{ ref('dim_building_age_category') }}
),

fact_building AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['p.bbl']) }} AS building_fact_key,

       {{ dbt_utils.generate_surrogate_key(['p.bbl']) }} AS location_key,
       {{ dbt_utils.generate_surrogate_key(['p.bbl']) }} AS building_key,
       ac.age_category_key,                                     -- ← now references the dim

       CAST(p.year_built AS INT64) AS year_built,
       CAST(p.year_alter1 AS INT64) AS yearalter1,
       CAST(p.year_alter2 AS INT64) AS yearalter2

   FROM pluto p
   LEFT JOIN age_categories ac ON p.building_age_category = ac.age_category_name
   WHERE p.bbl IS NOT NULL
)

SELECT * FROM fact_building