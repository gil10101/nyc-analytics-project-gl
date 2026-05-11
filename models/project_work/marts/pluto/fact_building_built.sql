-- Fact table for buildings (built / altered)
-- One row per BBL. Grain + measures come from stg_pluto.
-- Foreign keys looked up from dimensions.

WITH pluto AS (
    SELECT * FROM {{ ref('stg_pluto') }}
),

dim_location AS (
    SELECT bbl, location_key
    FROM {{ ref('dim_location_project') }}
),

dim_building AS (
    SELECT bbl, building_key
    FROM {{ ref('dim_building') }}
),

dim_age AS (
    SELECT age_category_name, age_category_key
    FROM {{ ref('dim_building_age_category') }}
),

fact_building AS (
    SELECT
        FARM_FINGERPRINT(CAST(p.bbl AS STRING)) AS building_fact_key,

        -- Foreign keys looked up from dimensions
        dl.location_key      AS location_key,
        db.building_key      AS building_key,
        da.age_category_key  AS age_category_key,

        -- Year measures
        CAST(p.year_built  AS INT64) AS year_built,
        CAST(p.year_alter1 AS INT64) AS yearalter1,
        CAST(p.year_alter2 AS INT64) AS yearalter2

    FROM pluto p
    LEFT JOIN dim_location dl
        ON CAST(p.bbl AS INT64) = dl.bbl
    LEFT JOIN dim_building db
        ON p.bbl = db.bbl
    LEFT JOIN dim_age da
        ON p.building_age_category = da.age_category_name

    WHERE p.bbl IS NOT NULL
)

SELECT * FROM fact_building