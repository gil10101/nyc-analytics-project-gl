-- Clean and standardize NYC PLUTO building/tax lot data
-- One row per tax lot (BBL)

WITH source AS (
   SELECT * FROM {{ source('project_raw', 'project_source_nyc_pluto_data') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           bbl,
           borocode,
           borough,
           block,
           lot,
           address,
           zipcode,
           cd,
           council,
           policeprct,
           landmark,
           latitude,
           longitude,
           landuse,
           bldgclass,
           numbldgs,
           numfloors,
           unitsres,
           unitstotal,
           lotarea,
           bldgarea,
           yearbuilt,
           yearalter1,
           yearalter2,
           assesstot
       ),

       -- Identifiers
       CAST(bbl AS STRING) AS bbl,
       CAST(borocode AS INT64) AS borocode,
       CAST(block AS INT64) AS block,
       CAST(lot AS INT64) AS lot,

       -- Standardize borough - PLUTO uses 2-char codes (MN, BX, BK, QN, SI)
       -- Match the same borough names produced in stg_311 so the join works downstream
       CASE
           WHEN UPPER(TRIM(borough)) = 'MN' THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) = 'BX' THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) = 'BK' THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) = 'QN' THEN 'Queens'
           WHEN UPPER(TRIM(borough)) = 'SI' THEN 'Staten Island'
           ELSE 'UNKNOWN'
       END AS borough,

       -- Location
       CAST(address AS STRING) AS address,

       -- Zip code - keep as STRING to preserve leading zeros
       CASE
           WHEN LENGTH(CAST(zipcode AS STRING)) = 5 THEN CAST(zipcode AS STRING)
           WHEN LENGTH(CAST(zipcode AS STRING)) = 4 THEN CONCAT('0', CAST(zipcode AS STRING))
           ELSE NULL
       END AS zipcode,

       -- cd in raw PLUTO is a 3-digit code: borough digit + 2-digit district (e.g. 108 = Manhattan CD8)
       -- Strip the leading borough digit to get the standalone community district number
       SAFE_CAST(MOD(CAST(cd AS INT64), 100) AS INT64) AS community_district,

       CAST(council AS INT64) AS council_district,
       CAST(policeprct AS INT64) AS police_precinct,
       CAST(landmark AS STRING) AS landmark,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Building details
       CAST(landuse AS STRING) AS land_use,
       CAST(bldgclass AS STRING) AS building_class,
       CAST(numbldgs AS INT64) AS num_buildings,
       CAST(numfloors AS DECIMAL) AS num_floors,
       CAST(unitsres AS INT64) AS units_residential,
       CAST(unitstotal AS INT64) AS units_total,
       CAST(lotarea AS INT64) AS lot_area,
       CAST(bldgarea AS INT64) AS building_area,
       CAST(assesstot AS FLOAT64) AS assessed_total_value,

       -- Year built and alterations
       CAST(yearbuilt AS INT64) AS year_built,
       CAST(yearalter1 AS INT64) AS year_alter1,
       CAST(yearalter2 AS INT64) AS year_alter2,

       -- Effective year - takes the most recent alteration if available, else year built
       -- This addresses the "weighing year altered vs year built" concern in the milestone doc
       CASE
           WHEN CAST(yearalter2 AS INT64) > 0 THEN CAST(yearalter2 AS INT64)
           WHEN CAST(yearalter1 AS INT64) > 0 THEN CAST(yearalter1 AS INT64)
           WHEN CAST(yearbuilt AS INT64) > 0 THEN CAST(yearbuilt AS INT64)
           ELSE NULL
       END AS effective_year,

       -- Building age (based on original year built)
       CASE
           WHEN CAST(yearbuilt AS INT64) > 0
           THEN EXTRACT(YEAR FROM CURRENT_DATE()) - CAST(yearbuilt AS INT64)
           ELSE NULL
       END AS building_age,

       -- Building age category - aligns with DimBuildingAgeCategory in dimensional model
       CASE
           WHEN CAST(yearbuilt AS INT64) = 0 OR yearbuilt IS NULL THEN 'Unknown'
           WHEN CAST(yearbuilt AS INT64) < 1900 THEN 'Pre-1900'
           WHEN CAST(yearbuilt AS INT64) BETWEEN 1900 AND 1939 THEN '1900-1939'
           WHEN CAST(yearbuilt AS INT64) BETWEEN 1940 AND 1969 THEN '1940-1969'
           WHEN CAST(yearbuilt AS INT64) BETWEEN 1970 AND 1999 THEN '1970-1999'
           WHEN CAST(yearbuilt AS INT64) BETWEEN 2000 AND 2009 THEN '2000-2009'
           WHEN CAST(yearbuilt AS INT64) >= 2010 THEN '2010-Present'
           ELSE 'Unknown'
       END AS building_age_category,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE bbl IS NOT NULL
   AND CAST(bbl AS STRING) != '0'
   AND borough IS NOT NULL
   AND CAST(yearbuilt AS INT64) > 0  -- Drop rows with no valid construction year (PLUTO uses 0 for unknown)

   -- Deduplicate on BBL - one row per tax lot
   QUALIFY ROW_NUMBER() OVER (PARTITION BY bbl ORDER BY yearbuilt DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table: stg_pluto