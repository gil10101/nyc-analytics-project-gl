-- Fact table for 311 complaints
-- One row per complaint. Grain + measures come from stg_311.
-- Foreign keys are looked up from the dimension tables (creates lineage edges).

WITH complaints AS (
    SELECT * FROM {{ ref('stg_311') }}
),

dim_location AS (
    SELECT bbl, location_key
    FROM {{ ref('dim_location_project') }}
),

dim_complaint_type AS (
    SELECT complaint_type, location_type, complaint_type_key
    FROM {{ ref('dim_complaint_type_project') }}
),

dim_date AS (
    SELECT full_date, date_key
    FROM {{ ref('dim_date_project') }}
),

fact_complaint AS (
    SELECT
        FARM_FINGERPRINT(CAST(c.request_id AS STRING)) AS complaint_key,

        -- Foreign keys looked up from dimensions
        d_created.date_key      AS created_date_key,
        d_closed.date_key       AS closed_date_key,
        dl.location_key         AS location_key,
        dct.complaint_type_key  AS complaint_type_key,

        -- Degenerate dimension (raw 311 ID for traceability)
        CAST(c.request_id AS INT64) AS unique_key,

        -- Measures
        1 AS complaint_count,
        CAST(c.days_to_close AS INT64) AS days_to_close

    FROM complaints c
    LEFT JOIN dim_location dl
        ON CAST(c.bbl AS INT64) = dl.bbl
    LEFT JOIN dim_complaint_type dct
        ON c.complaint_type = dct.complaint_type
       -- NULL-safe match because location_type can be NULL in both sides
       AND COALESCE(c.location_type, '__NULL__') = COALESCE(dct.location_type, '__NULL__')
    LEFT JOIN dim_date d_created
        ON CAST(c.created_date AS DATE) = d_created.full_date
    LEFT JOIN dim_date d_closed
        ON CAST(c.closed_date AS DATE) = d_closed.full_date

    WHERE c.request_id     IS NOT NULL
      AND c.created_date   IS NOT NULL
      AND c.bbl            IS NOT NULL
      AND c.complaint_type IS NOT NULL
)

SELECT * FROM fact_complaint