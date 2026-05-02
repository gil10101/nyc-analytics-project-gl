-- Clean and standardize 311 HPD service request data
-- Filtered to heat, hot water, plumbing, and paint complaints
-- One row per service request

WITH source AS (
   SELECT * FROM {{ source('raw', 'project_nyc_311_raw_data.project_source_nyc_311_complaints') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           unique_key,
           created_date,
           closed_date,
           agency,
           agency_name,
           complaint_type,
           descriptor,
           descriptor_2,
           status,
           incident_zip,
           borough,
           incident_address,
           street_name,
           cross_street_1,
           cross_street_2,
           latitude,
           longitude,
           bbl,
           open_data_channel_type,
           resolution_description,
           resolution_action_updated_date,
           community_board,
           council_district,
           police_precinct
       ),

       -- Identifiers
       CAST(unique_key AS STRING) AS request_id,
       CAST(bbl AS STRING) AS bbl,

       -- Date/Time
       CAST(created_date AS TIMESTAMP) AS created_date,
       CAST(closed_date AS TIMESTAMP) AS closed_date,
       CAST(resolution_action_updated_date AS TIMESTAMP) AS resolution_action_updated_date,

       -- Derived date fields for trend analysis
       DATE(created_date) AS created_date_only,
       EXTRACT(YEAR FROM created_date) AS created_year,
       EXTRACT(MONTH FROM created_date) AS created_month,

       -- Resolution time in days (NULL if still open)
       CASE
           WHEN closed_date IS NOT NULL AND created_date IS NOT NULL
           THEN DATE_DIFF(DATE(closed_date), DATE(created_date), DAY)
           ELSE NULL
       END AS days_to_close,

       -- Request details
       CAST(agency AS STRING) AS agency,
       CAST(agency_name AS STRING) AS agency_name,
       CAST(complaint_type AS STRING) AS complaint_type,
       CAST(descriptor AS STRING) AS descriptor,
       CAST(descriptor_2 AS STRING) AS descriptor_2,
       UPPER(TRIM(CAST(status AS STRING))) AS status,
       CAST(resolution_description AS STRING) AS resolution_description,

       -- Normalize complaint into broad categories aligned with project scope
       -- Note: '%HEAT%' covers HEAT/HOT WATER which is a single complaint_type in the raw data
       CASE
           WHEN UPPER(complaint_type) LIKE '%HEAT%' OR UPPER(complaint_type) LIKE '%HOT WATER%' THEN 'Heat/Hot Water'
           WHEN UPPER(complaint_type) LIKE '%PLUMB%' THEN 'Plumbing'
           WHEN UPPER(complaint_type) LIKE '%PAINT%' THEN 'Paint/Plaster'
           WHEN UPPER(complaint_type) LIKE '%WATER%' THEN 'Water'
           ELSE 'Other'
       END AS complaint_category,

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(incident_zip AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(incident_zip AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(incident_zip AS STRING)) = 5 THEN CAST(incident_zip AS STRING)
           WHEN LENGTH(CAST(incident_zip AS STRING)) = 9 THEN CAST(incident_zip AS STRING)
           WHEN LENGTH(CAST(incident_zip AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(incident_zip AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(incident_zip AS STRING)
           ELSE NULL
       END AS incident_zip,

       -- Location - standardized borough; raw data uses values like 'BROOKLYN', 'QUEENS' (uppercase)
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       CAST(incident_address AS STRING) AS incident_address,
       CAST(street_name AS STRING) AS street_name,
       CAST(cross_street_1 AS STRING) AS cross_street_1,
       CAST(cross_street_2 AS STRING) AS cross_street_2,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- community_board in raw data is formatted like "10 BROOKLYN" - extract the leading number
       SAFE_CAST(REGEXP_EXTRACT(CAST(community_board AS STRING), r'^(\d+)') AS INT64) AS community_board,

       CAST(council_district AS INT64) AS council_district,

       -- police_precinct in raw data is formatted like "Precinct 68" - extract the number
       SAFE_CAST(REGEXP_EXTRACT(CAST(police_precinct AS STRING), r'(\d+)') AS INT64) AS police_precinct,

       -- Clearer column name as well for this one
       CAST(open_data_channel_type AS STRING) AS method_of_submission,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE (agency = 'HPD' OR agency_name LIKE '%Housing Preservation%')
   AND unique_key IS NOT NULL
   AND created_date IS NOT NULL
   AND bbl IS NOT NULL
   AND CAST(bbl AS STRING) != '0'
   AND latitude IS NOT NULL
   AND longitude IS NOT NULL
   AND borough IS NOT NULL
   AND (
       UPPER(complaint_type) LIKE '%HEAT%'
       OR UPPER(complaint_type) LIKE '%HOT WATER%'
       OR UPPER(complaint_type) LIKE '%WATER%'
       OR UPPER(complaint_type) LIKE '%PLUMB%'
       OR UPPER(complaint_type) LIKE '%PAINT%'
   )
   AND (resolution_description IS NULL OR UPPER(resolution_description) NOT LIKE '%DUPLICATE%')

   -- Deduplicate - addresses ~20% duplicate rate flagged in milestone doc
   -- Treat rows with same BBL, complaint_type, descriptor, and created_date as duplicates
   QUALIFY ROW_NUMBER() OVER (
       PARTITION BY bbl, complaint_type, descriptor, created_date
       ORDER BY created_date DESC, unique_key
   ) = 1
)

SELECT * FROM cleaned
-- All should be part of this table: stg_311