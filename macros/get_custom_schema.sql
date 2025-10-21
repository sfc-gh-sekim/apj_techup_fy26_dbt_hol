-- Overrides default dbt behaviour on schema handling. See https://docs.getdbt.com/docs/build/custom-schemas#a-built-in-alternative-pattern-for-generating-schema-names
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ generate_schema_name_for_env(custom_schema_name, node) }}
{%- endmacro %}