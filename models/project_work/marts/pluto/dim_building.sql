-- Building dimension
-- One row per BBL with building-level attributes.
-- bbl is exposed as a natural key so fact tables can join on it (lineage edge).

WITH building_dimension AS (
    SELECT
        FARM_FINGERPRINT(CAST(bbl AS STRING)) AS building_key,

        -- Natural key (not in the published ERD, but required for fact joins)
        CAST(bbl AS STRING) AS bbl,

        CAST(units_total   AS INT64)   AS total_units,
        CAST(num_floors    AS NUMERIC) AS num_floors,
        CAST(lot_area      AS INT64)   AS lot_area,
        CAST(building_area AS INT64)   AS bldg_area,
        CAST(num_buildings AS INT64)   AS building_count,
        CAST(land_use      AS STRING)  AS land_use

    FROM {{ ref('stg_pluto') }}
    WHERE bbl IS NOT NULL
)

SELECT * FROM building_dimension