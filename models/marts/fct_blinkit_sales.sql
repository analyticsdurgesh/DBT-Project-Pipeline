-- Purpose:
-- This model creates the main sales fact table.
-- A fact table stores the detailed business events we want to analyze.
-- Here, each row represents one Blinkit sales record from the CSV.

with orders as (
    -- Start from the cleaned staging view, not the raw table.
    select *
    from {{ ref('stg_blinkit_orders') }}
),

numbered as (
    select
        -- The CSV does not have a natural unique order id.
        -- We create a stable row number so each record can get a unique key.
        row_number() over (
            order by
                item_identifier,
                outlet_identifier,
                item_visibility,
                item_weight,
                sales,
                rating
        ) as source_row_number,
        *
    from orders
)

select
    -- Build a unique key for each sales row.
    -- md5 creates a compact id from row number + item + outlet.
    md5(
        source_row_number::varchar
        || '|'
        || coalesce(item_identifier, '')
        || '|'
        || coalesce(outlet_identifier, '')
    ) as blinkit_sale_key,

    -- Keep the clean columns needed for analysis.
    source_row_number,
    item_identifier,
    item_type,
    item_fat_content,
    outlet_identifier,
    outlet_establishment_year,
    outlet_location_type,
    outlet_size,
    outlet_type,
    item_visibility,
    item_weight,
    sales,
    rating
from numbered
