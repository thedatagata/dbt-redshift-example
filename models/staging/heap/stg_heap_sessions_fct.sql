{{
    config(
        sort = 'heap_session_start_time',
        dist = 'heap_session_id',
        unique_key = 'heap_session_id'
    )
}}



-- here is the dbt util function for pivot (https://github.com/dbt-labs/dbt-utils#pivot-source)
WITH funnel_pivot 
        AS 
            (
                SELECT
                    e.heap_user_id 
                  , e.heap_session_id 
                  , {{ dbt_utils.pivot('heap_event_funnel_position', dbt_utils.get_column_values(ref('stg_heap_events_fct'),'heap_event_funnel_position'), prefix=var('funnel_prefix')}}
                  , SUM(CASE WHEN e.heap_is_conversion_event THEN 1 ELSE 0 END) AS heap_session_conversion_cnt
                  
                -- we only want to update users who have had activity since the last run 
                FROM {{ ref('stg_heap_events_fct') }} e 
                WHERE e.heap_event_funnel_position IS NOT NULL 
                {% if is_incremental() %}
                  AND e.heap_user_id IN ({{get_active_users('heap_session_start_time')}})
                {% endif %}
                GROUP BY 1,2
            )

SELECT
    s.heap_session_id 
  , s.heap_user_id 
  , s.heap_session_index
  , s.heap_session_start_time 
  , s.heap_session_end_time 
  , s.heap_session_look_forward 
  , fp.*
  -- flag every session where there was a registration
  , CASE WHEN fp.heap_session_conversion_cnt > 0 THEN 1 ELSE 0 END AS heap_session_conversion
  , s.heap_session_country
  , s.heap_session_region
  , s.heap_session_city 
  , s.heap_session_ip 
  , s.heap_session_referrer 
  , s.heap_session_landing_page
  , s.heap_session_landing_page_query 
  , s.heap_session_landing_page_hash 
  , s.heap_session_browser
  , s.heap_session_utm_source
  , s.heap_session_utm_campaign
  , s.heap_session_utm_medium 
  , s.heap_session_utm_term 
  , s.heap_session_utm_content


FROM {{ ref('src_heap_sessions_eph') }} s
LEFT JOIN funnel_pivot fp
    ON s.heap_user_id = fp.heap_user_id
    AND s.heap_session_id = fp.heap_session_id 





    