{% macro get_funnel_event_sources() %}
    {% for event_obj in var('funnel_events') %}
        SELECT DISTINCT '{{event_obj["event_name"]}}' as heap_funnel_event_name, e.heap_event_source FROM {{ source('heap', event_obj["event_name"]) }} e 
        {% if not loop.last -%} union all {% endif -%}
    {% endfor %}
{% endmacro %}