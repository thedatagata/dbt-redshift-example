{% macro gen_user_funnel_rollup() %}
    
    {% for i in range( var('funnel_step_cnt') ) %}
        SUM( s.{{ var('funnel_prefix') ~ loop.index | string() }} ) AS heap_user_{{var('funnel_prefix') ~ loop.index | string() }},
    {% endfor %}

{% endmacro %}