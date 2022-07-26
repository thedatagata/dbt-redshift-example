{% macro check_funnel_position(heap_event_name) %}
    CASE 
        {%- for event_obj in var('funnel_events') %}
            WHEN {{heap_event_name}} = '{{event_obj["event_name"]}}' THEN {{event_obj["funnel_position"]}}
        {% endfor %}
    ELSE 0 
    END
{% endmacro %}