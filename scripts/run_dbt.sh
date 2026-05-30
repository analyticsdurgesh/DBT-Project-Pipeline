#!/usr/bin/env bash
set -euo pipefail

if [ ! -f profiles.yml ]; then
  echo "Missing profiles.yml"
  echo "Copy profiles.yml.example to profiles.yml and fill in your Snowflake values."
  exit 1
fi

dbt debug --profiles-dir .
dbt build --profiles-dir .
