-- Purpose:
-- This script is the Snowflake setup step for the project.
-- Run it one time in a Snowflake worksheet before running dbt from VS Code.
--
-- What it does:
-- 1. Creates a small Snowflake warehouse for compute.
-- 2. Creates a database and schemas.
-- 3. Creates a CSV file format so Snowflake understands the S3 file.
-- 4. Creates an external stage that points to the S3 bucket.
-- 5. Creates a raw table with the same column names as the CSV.
-- 6. Copies the S3 CSV data into the raw Snowflake table.
--
-- Important:
-- Replace <YOUR_AWS_KEY_ID> and <YOUR_AWS_SECRET_KEY> before running.
-- Do not commit real AWS keys or Snowflake passwords into project files.

-- Use ACCOUNTADMIN because this script creates warehouses, databases, schemas,
-- stages, and tables. A smaller custom role is better for production later.
USE ROLE ACCOUNTADMIN;

-- The warehouse is the compute engine Snowflake uses to run SQL.
-- XSMALL is enough for this learning project and auto-suspends after 60 seconds
-- to avoid unnecessary cost.
CREATE WAREHOUSE IF NOT EXISTS BLINKIT_WH
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- The database is the top-level container for all project tables and views.
CREATE DATABASE IF NOT EXISTS BLINKIT_DB;

-- RAW stores data exactly as it came from S3.
-- STAGING stores cleaned dbt views.
-- MARTS stores final analytics tables built by dbt.
CREATE SCHEMA IF NOT EXISTS BLINKIT_DB.RAW;
CREATE SCHEMA IF NOT EXISTS BLINKIT_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS BLINKIT_DB.MARTS;

-- Tell Snowflake where to run the next SQL commands.
USE WAREHOUSE BLINKIT_WH;
USE DATABASE BLINKIT_DB;
USE SCHEMA RAW;

-- This file format tells Snowflake how to read blinkit_orders.csv.
-- SKIP_HEADER = 1 means the first row contains column names, not data.
-- EMPTY_FIELD_AS_NULL and NULL_IF convert blank values into real SQL NULLs.
CREATE OR REPLACE FILE FORMAT BLINKIT_CSV_FORMAT
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('', 'NULL', 'null');

-- A stage is Snowflake's pointer to external files.
-- Here, it points to your AWS S3 bucket.
-- Replace the two placeholder credential values before running this script.
CREATE OR REPLACE STAGE BLINKIT_S3_STAGE
  URL = 's3://blinkit-sales-bucket'
  CREDENTIALS = (
    AWS_KEY_ID = '<YOUR_AWS_KEY_ID>'
    AWS_SECRET_KEY = '<YOUR_AWS_SECRET_KEY>'
  )
  FILE_FORMAT = BLINKIT_CSV_FORMAT;

-- Optional check: uncomment this line if your AWS key has s3:ListBucket.
-- It should show blinkit_orders.csv.
-- LIST @BLINKIT_S3_STAGE;

-- This raw table keeps the CSV column names exactly as they are.
-- Because the CSV headers contain spaces, each column name is wrapped in
-- double quotes. dbt will rename these columns to clean snake_case later.
CREATE OR REPLACE TABLE BLINKIT_ORDERS_RAW (
  "Item Fat Content" VARCHAR,
  "Item Identifier" VARCHAR,
  "Item Type" VARCHAR,
  "Outlet Establishment Year" VARCHAR,
  "Outlet Identifier" VARCHAR,
  "Outlet Location Type" VARCHAR,
  "Outlet Size" VARCHAR,
  "Outlet Type" VARCHAR,
  "Item Visibility" VARCHAR,
  "Item Weight" VARCHAR,
  "Sales" VARCHAR,
  "Rating" VARCHAR
);

-- Load the CSV file from S3 into the raw Snowflake table.
-- FORCE = TRUE reloads the file even if Snowflake loaded it before.
-- ON_ERROR = 'ABORT_STATEMENT' stops the load if any row has a serious issue.
COPY INTO BLINKIT_ORDERS_RAW
FROM @BLINKIT_S3_STAGE/blinkit_orders.csv
FILE_FORMAT = (FORMAT_NAME = BLINKIT_CSV_FORMAT)
ON_ERROR = 'ABORT_STATEMENT'
FORCE = TRUE;

-- Final check: this should return the number of rows loaded into Snowflake.
-- Your local CSV has 8,523 data rows, so Snowflake should normally show 8523.
SELECT COUNT(*) AS raw_rows_loaded
FROM BLINKIT_ORDERS_RAW;
