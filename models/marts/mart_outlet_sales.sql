-- Purpose:
-- This is a final analytics table for outlet-level reporting.
-- It groups all sales rows by outlet and calculates useful business metrics.

select
    -- This key is unique for each outlet summary row.
    -- Some outlet IDs appear with multiple outlet_size values in the CSV,
    -- so outlet_identifier alone is not unique enough for this table.
    md5(
        coalesce(outlet_identifier, '')
        || '|'
        || coalesce(outlet_establishment_year::varchar, '')
        || '|'
        || coalesce(outlet_location_type, '')
        || '|'
        || coalesce(outlet_size, '')
        || '|'
        || coalesce(outlet_type, '')
    ) as outlet_sales_key,

    -- Outlet details used to group the data.
    outlet_identifier,
    outlet_establishment_year,
    outlet_location_type,
    outlet_size,
    outlet_type,

    -- Metrics that are useful for dashboards and analysis.
    count(*) as order_count,
    sum(sales) as total_sales,
    avg(sales) as avg_sales,
    avg(rating) as avg_rating,
    avg(item_weight) as avg_item_weight
from {{ ref('fct_blinkit_sales') }}

-- One output row per outlet.
group by
    outlet_identifier,
    outlet_establishment_year,
    outlet_location_type,
    outlet_size,
    outlet_type
