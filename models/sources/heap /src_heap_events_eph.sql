
-- if dbt_project.yml file has gen_new_sessions set to true, we need to apply the session ids created in src_heap_pageviews to every event
{% if var('gen_new_sessions') %}
    WITH 
        sessions_base 
            AS 
                (
                    SELECT *
                    FROM {{ ref('src_heap_pageviews_eph') }} p 
                    WHERE p.heap_session_start_flag = 1 
                )
    SELECT 
        e.heap_event_id
      , e.heap_event_name
      , e.heap_user_id
      , s.heap_session_id_new AS heap_session_id 
      , e.heap_event_time 

    FROM {{ source('heap','all_events') }} e 
    LEFT JOIN sessions_base s 
        ON s.heap_user_id = e.heap_user_id 
        AND s.heap_pageview_source = e.heap_event_source 
        AND e.heap_event_time BETWEEN s.heap_pageview_time AND s.heap_session_end_time
    
    {% if is_incremental() %}
        WHERE e.heap_user_id IN ({{get_active_users()}})
    {% endif %}
                
{% else %}
    SELECT * 
    FROM {{ source('heap','all_events') }}

    {% if is_incremental() %}
        WHERE e.heap_user_id IN ({{get_active_users('heap_event_time')}})
    {% endif %}
{% endif %}