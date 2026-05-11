-- Clean and standardize NYC Open Restaurant application data
-- One row per restaurant application

WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
    SELECT
        * EXCEPT (
            objectid,
            restaurant_name,
            legal_business_name,
            food_service_establishment,
            borough,
            zip,
            business_address,
            seating_interest_sidewalk,
            sidewalk_dimensions_area,
            roadway_dimensions_area,
            approved_for_sidewalk_seating,
            approved_for_roadway_seating,
            time_of_submission,
            latitude,
            longitude
        ),

        -- Identifiers
        CAST(objectid AS STRING) AS application_id,

        -- Business Identity
        TRIM(CAST(restaurant_name AS STRING)) AS restaurant_name,
        TRIM(CAST(legal_business_name AS STRING)) AS legal_business_name,
        CAST(food_service_establishment AS STRING) AS food_service_establishment_permit,

        -- Location - standardized borough
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Location - clean zip code
        CASE
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', '') THEN NULL
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 5 THEN TRIM(CAST(zip AS STRING))
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 9 THEN TRIM(CAST(zip AS STRING))
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 10
                AND REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{5}-\d{4}')
            THEN TRIM(CAST(zip AS STRING))
            ELSE NULL
        END AS zip,

        TRIM(CAST(business_address AS STRING)) AS business_address,

        -- Seating Type - standardize
        UPPER(TRIM(CAST(seating_interest_sidewalk AS STRING))) AS seating_interest,

        -- Core Metrics
        CAST(sidewalk_dimensions_area AS FLOAT64) AS sidewalk_area_sqft,
        CAST(roadway_dimensions_area AS FLOAT64) AS roadway_area_sqft,

        -- Approval Status - standardize to boolean-friendly values
        UPPER(TRIM(CAST(approved_for_sidewalk_seating AS STRING))) AS approved_for_sidewalk_seating,
        UPPER(TRIM(CAST(approved_for_roadway_seating AS STRING))) AS approved_for_roadway_seating,

        -- Submission Time
        CAST(time_of_submission AS TIMESTAMP) AS submitted_at,

        -- Geospatial
        CAST(latitude AS FLOAT64) AS latitude,
        CAST(longitude AS FLOAT64) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE objectid IS NOT NULL
      AND time_of_submission IS NOT NULL
      AND borough IS NOT NULL

    -- Deduplicate
    QUALIFY ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY time_of_submission DESC) = 1
)

SELECT * FROM cleaned
-- stg_nyc_open_restaurant_apps