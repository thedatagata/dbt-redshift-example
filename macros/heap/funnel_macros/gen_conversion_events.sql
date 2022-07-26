{% macro gen_conversion_events() %}
  (
    {%- for event_obj in var('funnel_events') -%}
        {%- if event_obj["is_conversion"] -%}
            '{{ event_obj["event_name"] }}' {{ "," if not loop.last }}
        {%- endif -%}
    {%- endfor -%}
  )
{% endmacro %}