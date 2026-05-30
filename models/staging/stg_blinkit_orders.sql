-- Purpose:
-- This is the first dbt transformation after loading the CSV into Snowflake.
-- It reads the raw table, cleans the column names, trims text, and converts
-- number-like text into real numeric columns.

with source as (
    -- Read from the raw Snowflake table declared in src_blinkit.yml.
    select *
    from {{ source('blinkit_raw', 'blinkit_orders_raw') }}
),

renamed as (
    select
        -- The raw CSV headers contain spaces, so raw columns need double quotes.
        -- The `as item_fat_content` part gives each column a clean dbt name.
        nullif(trim("Item Fat Content"), '') as item_fat_content,
        nullif(trim("Item Identifier"), '') as item_identifier,
        nullif(trim("Item Type"), '') as item_type,

        -- TRY_TO_NUMBER / TRY_TO_DECIMAL safely convert text into numbers.
        -- If a value cannot be converted, Snowflake returns NULL instead of
        -- failing the whole dbt run.
        try_to_number("Outlet Establishment Year")::integer as outlet_establishment_year,
        nullif(trim("Outlet Identifier"), '') as outlet_identifier,
        nullif(trim("Outlet Location Type"), '') as outlet_location_type,
        nullif(trim("Outlet Size"), '') as outlet_size,
        nullif(trim("Outlet Type"), '') as outlet_type,
        try_to_decimal("Item Visibility", 18, 9) as item_visibility,
        try_to_decimal("Item Weight", 10, 3) as item_weight,
        try_to_decimal("Sales", 18, 4) as sales,
        try_to_decimal("Rating", 4, 2) as rating
    from source
)

-- Final output of this staging view.
select *
from renamed
