-- Building age category dimension
-- Static reference table with predefined age buckets

WITH category_definitions AS (
    SELECT 'Pre-1900'     AS age_category_name, 0    AS min_year_built, 1899 AS max_year_built, 1 AS sort_order UNION ALL
    SELECT '1900-1939'    AS age_category_name, 1900 AS min_year_built, 1939 AS max_year_built, 2 AS sort_order UNION ALL
    SELECT '1940-1969'    AS age_category_name, 1940 AS min_year_built, 1969 AS max_year_built, 3 AS sort_order UNION ALL
    SELECT '1970-1999'    AS age_category_name, 1970 AS min_year_built, 1999 AS max_year_built, 4 AS sort_order UNION ALL
    SELECT '2000-2009'    AS age_category_name, 2000 AS min_year_built, 2009 AS max_year_built, 5 AS sort_order UNION ALL
    SELECT '2010-Present' AS age_category_name, 2010 AS min_year_built, 9999 AS max_year_built, 6 AS sort_order
),

-- Only keep categories that actually appear in the data
used_categories AS (
    SELECT DISTINCT building_age_category AS age_category_name
    FROM {{ ref('stg_pluto') }}
),

age_category_dimension AS (
    SELECT
        FARM_FINGERPRINT(CAST(cd.age_category_name AS STRING)) AS age_category_key,
        CAST(cd.age_category_name AS STRING) AS age_category_name,
        CAST(cd.min_year_built    AS INT64)  AS min_year_built,
        CAST(cd.max_year_built    AS INT64)  AS max_year_built,
        CAST(cd.sort_order        AS INT64)  AS sort_order
    FROM category_definitions cd
    INNER JOIN used_categories uc
        ON cd.age_category_name = uc.age_category_name
)

SELECT * FROM age_category_dimension