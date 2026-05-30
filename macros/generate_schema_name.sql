{#
    Purpose:
    dbt normally combines the target schema and custom schema name.
    Example: STAGING + marts can become STAGING_MARTS.

    For this project, we want simple schema names:
    - staging models go to BLINKIT_DB.STAGING
    - mart models go to BLINKIT_DB.MARTS

    This macro makes dbt use the schema name exactly as written in
    dbt_project.yml.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {# If no custom schema is set, use the default schema from profiles.yml. #}
        {{ target.schema }}
    {%- else -%}
        {# If a custom schema is set, use it directly. #}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
