-- Location dimension shared by 311 complaints and PLUTO buildings
-- One row per unique BBL (tax lot)
-- Built primarily from PLUTO since it is the authoritative source of lot/location data,
-- with 311-only locations unioned in to cover any complaints whose BBL is not in PLUTO

WITH pluto_locations AS (
   SELECT
       bbl,
       borough AS borough_name,
       block,
       lot,
       community_district,
       council_district,
       police_precinct,
       zipcode AS zip_code,
       landmark,
       latitude,
       longitude
   FROM {{ ref('stg_pluto') }}
),

complaint_locations AS (
   -- Pull location info from 311 for any BBLs not present in PLUTO
   SELECT
       c.bbl,
       c.borough AS borough_name,
       SAFE_CAST(SUBSTR(c.bbl, 2, 5) AS INT64) AS block,
       SAFE_CAST(SUBSTR(c.bbl, 7, 4) AS INT64) AS lot,
       c.community_board AS community_district,
       c.council_district,
       c.police_precinct,
       c.incident_zip AS zip_code,
       CAST(NULL AS STRING) AS landmark,
       c.latitude,
       c.longitude
   FROM {{ ref('stg_311') }} c
   LEFT JOIN pluto_locations p ON c.bbl = p.bbl
   WHERE p.bbl IS NULL
     AND c.bbl IS NOT NULL
   QUALIFY ROW_NUMBER() OVER (PARTITION BY c.bbl ORDER BY c.created_date DESC) = 1
),

all_locations AS (
   SELECT * FROM pluto_locations
   UNION ALL
   SELECT * FROM complaint_locations
),

location_dimension AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['bbl']) }} AS location_key,

       CAST(bbl AS INT64) AS bbl,
       CAST(borough_name AS STRING) AS borough_name,
       CAST(block AS INT64) AS block,
       CAST(lot AS INT64) AS lot,
       CAST(community_district AS INT64) AS community_district,
       CAST(council_district AS INT64) AS council_district,
       CAST(police_precinct AS INT64) AS police_precinct,
       CAST(zip_code AS STRING) AS zip_code,
       CAST(landmark AS STRING) AS landmark,
       CAST(latitude AS NUMERIC) AS latitude,
       CAST(longitude AS NUMERIC) AS longitude

   FROM all_locations
   WHERE bbl IS NOT NULL
)

SELECT * FROM location_dimension