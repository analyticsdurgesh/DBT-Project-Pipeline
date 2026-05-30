#!/usr/bin/env python3
"""Run the full Blinkit pipeline: Snowflake bootstrap, dbt build, row checks."""

from __future__ import annotations

import os
import json
import shutil
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LOCAL_CONFIG_FILE = PROJECT_ROOT / "config" / "local_credentials.json"
BOOTSTRAP_SQL = PROJECT_ROOT / "sql" / "bootstrap_snowflake.sql"
REQUIREMENTS_FILE = PROJECT_ROOT / "requirements.txt"


REQUIRED_SNOWFLAKE_KEYS = ["account", "user", "password"]
REQUIRED_AWS_KEYS = ["access_key_id", "secret_access_key"]


def ensure_project_python() -> None:
    """Create .venv when missing, then re-run with project Python."""
    local_python = PROJECT_ROOT / ".venv" / "bin" / "python"
    if not local_python.exists():
        print("Creating local Python environment in .venv ...", flush=True)
        subprocess.run([sys.executable, "-m", "venv", str(PROJECT_ROOT / ".venv")], check=True)
        print("Installing Python packages from requirements.txt ...", flush=True)
        subprocess.run([str(local_python), "-m", "pip", "install", "-r", str(REQUIREMENTS_FILE)], check=True)

    if Path(sys.executable) == local_python:
        return

    os.execv(str(local_python), [str(local_python), *sys.argv])


def load_local_config() -> dict:
    """Load local-only credentials from config/local_credentials.json."""
    if not LOCAL_CONFIG_FILE.exists():
        raise SystemExit(
            "Missing config/local_credentials.json\n"
            "Copy config/local_credentials.example.json to config/local_credentials.json "
            "and fill in your local Snowflake and AWS values."
        )
    config = json.loads(LOCAL_CONFIG_FILE.read_text(encoding="utf-8"))
    snowflake_config = config.get("snowflake", {})
    aws_config = config.get("aws", {})
    _require_keys(snowflake_config, REQUIRED_SNOWFLAKE_KEYS, "snowflake")
    _require_keys(aws_config, REQUIRED_AWS_KEYS, "aws")
    return config


def _require_keys(config: dict, required_keys: list[str], section: str) -> None:
    missing = [key for key in required_keys if not str(config.get(key, "")).strip()]
    placeholders = [
        key
        for key in required_keys
        if str(config.get(key, "")).strip().lower().startswith("your_")
    ]
    if missing or placeholders:
        problems = ", ".join(sorted(set(missing + placeholders)))
        raise SystemExit(f"Update config/local_credentials.json: {section}.{problems}")


def config_value(config: dict, key: str, default: str) -> str:
    """Read a Snowflake config value with a project default."""
    return str(config.get("snowflake", {}).get(key, default)).strip()


def run_snowflake_bootstrap(config: dict) -> None:
    """Create Snowflake objects and load the S3 CSV into the raw table."""
    try:
        import snowflake.connector
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "Snowflake connector is not installed.\n"
            "Run: python scripts/run_pipeline.py again so the project environment can be rebuilt."
        ) from exc

    sql_text = BOOTSTRAP_SQL.read_text()
    sql_text = sql_text.replace("<YOUR_AWS_KEY_ID>", config["aws"]["access_key_id"])
    sql_text = sql_text.replace("<YOUR_AWS_SECRET_KEY>", config["aws"]["secret_access_key"])

    connection = snowflake.connector.connect(
        account=config_value(config, "account", ""),
        user=config_value(config, "user", ""),
        password=config_value(config, "password", ""),
        role=config_value(config, "role", "ACCOUNTADMIN"),
    )

    try:
        cursors = connection.execute_string(sql_text)
        for cursor in cursors:
            if cursor.description and cursor.description[0][0] == "RAW_ROWS_LOADED":
                raw_rows_loaded = cursor.fetchone()[0]
                print(f"Snowflake raw load complete: {raw_rows_loaded} rows", flush=True)
    finally:
        connection.close()


def run_command(command: list[str]) -> None:
    """Run a terminal command from the project root and fail if it fails."""
    print(f"Running: {' '.join(command)}", flush=True)
    subprocess.run(command, cwd=PROJECT_ROOT, check=True)


def dbt_executable() -> str:
    """Find dbt from PATH or from the local virtual environment."""
    dbt = shutil.which("dbt")
    if dbt:
        return dbt

    local_dbt = PROJECT_ROOT / ".venv" / "bin" / "dbt"
    if local_dbt.exists():
        return str(local_dbt)

    raise SystemExit("dbt not found. Run: python scripts/run_pipeline.py again so the project environment can be rebuilt.")


def run_dbt() -> None:
    """Run dbt connection checks, models, and tests."""
    dbt = dbt_executable()
    run_command([dbt, "debug", "--profiles-dir", "."])
    run_command([dbt, "build", "--profiles-dir", "."])


def print_row_counts(config: dict) -> None:
    """Print final Snowflake row counts for quick verification."""
    try:
        import snowflake.connector
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "Snowflake connector is not installed.\n"
            "Run: python scripts/run_pipeline.py again so the project environment can be rebuilt."
        ) from exc

    connection = snowflake.connector.connect(
        account=config_value(config, "account", ""),
        user=config_value(config, "user", ""),
        password=config_value(config, "password", ""),
        role=config_value(config, "role", "ACCOUNTADMIN"),
        warehouse=config_value(config, "warehouse", "BLINKIT_WH"),
        database=config_value(config, "database", "BLINKIT_DB"),
        schema=config_value(config, "schema", "STAGING"),
    )

    checks = [
        ("raw_rows", "select count(*) from BLINKIT_DB.RAW.BLINKIT_ORDERS_RAW"),
        ("staging_rows", "select count(*) from BLINKIT_DB.STAGING.STG_BLINKIT_ORDERS"),
        ("fact_rows", "select count(*) from BLINKIT_DB.MARTS.FCT_BLINKIT_SALES"),
        ("outlet_mart_rows", "select count(*) from BLINKIT_DB.MARTS.MART_OUTLET_SALES"),
    ]

    try:
        cursor = connection.cursor()
        for label, query in checks:
            cursor.execute(query)
            print(f"{label}: {cursor.fetchone()[0]}", flush=True)
    finally:
        connection.close()


def main() -> None:
    """Run the pipeline in the correct order."""
    config = load_local_config()

    run_snowflake_bootstrap(config)
    run_dbt()
    print_row_counts(config)
    print("Pipeline completed successfully.", flush=True)


if __name__ == "__main__":
    ensure_project_python()
    main()
