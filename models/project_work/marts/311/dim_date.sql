-- Date dimension shared by 311 complaints and PLUTO building data

WITH all_dates AS (
   -- Get dates from 311 complaints (created and closed dates)
   SELECT DISTINCT CAST(created_date AS DATE) AS full_date
   FROM {{ ref('stg_311') }}
   WHERE created_date IS NOT NULL

   UNION DISTINCT

   SELECT DISTINCT CAST(closed_date AS DATE) AS full_date
   FROM {{ ref('stg_311') }}
   WHERE closed_date IS NOT NULL
),

date_dimension AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['full_date']) }} AS date_key,

       full_date,
       EXTRACT(DAY FROM full_date) AS day,
       EXTRACT(MONTH FROM full_date) AS month,
       FORMAT_DATE('%B', full_date) AS month_name,
       EXTRACT(QUARTER FROM full_date) AS quarter,
       EXTRACT(YEAR FROM full_date) AS year,
       FORMAT_DATE('%A', full_date) AS day_of_week

   FROM all_dates
)

SELECT * FROM date_dimension