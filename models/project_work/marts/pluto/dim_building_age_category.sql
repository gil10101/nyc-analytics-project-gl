-- Building age category dimension
-- Static reference table with predefined age buckets

WITH age_categories AS (
   SELECT 'Pre-1900'      AS age_category_name, 0    AS min_year_built, 1899 AS max_year_built, 1 AS sort_order UNION ALL
   SELECT '1900-1939'     AS age_category_name, 1900 AS min_year_built, 1939 AS max_year_built, 2 AS sort_order UNION ALL
   SELECT '1940-1969'     AS age_category_name, 1940 AS min_year_built, 1969 AS max_year_built, 3 AS sort_order UNION ALL
   SELECT '1970-1999'     AS age_category_name, 1970 AS min_year_built, 1999 AS max_year_built, 4 AS sort_order UNION ALL
   SELECT '2000-2009'     AS age_category_name, 2000 AS min_year_built, 2009 AS max_year_built, 5 AS sort_order UNION ALL
   SELECT '2010-Present'  AS age_category_name, 2010 AS min_year_built, 9999 AS max_year_built, 6 AS sort_order
),

age_category_dimension AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['age_category_name']) }} AS age_category_key,

       CAST(age_category_name AS STRING) AS age_category_name,
       CAST(min_year_built AS INT64) AS min_year_built,
       CAST(max_year_built AS INT64) AS max_year_built,
       CAST(sort_order AS INT64) AS sort_order

   FROM age_categories
)

SELECT * FROM age_category_dimension