
-- if the dbt_project gen_new_session variable is set to true, this model will create a pageviews source table with new session ids 
{% if var('gen_new_sessions') %}

WITH 
    pageviews_lag
        AS 
            (
                -- have every pageview timestamp on the same row as the previous pageview
                SELECT
                    p.*
                  , EXTRACT(EPOCH FROM p.heap_pageview_time) as heap_pageview_epoch
                  , LAG(EXTRACT(EPOCH FROM p.heap_pageview_time),1) OVER(PARTITION BY p.heap_user_id, p.heap_pageview_source ORDER BY p.heap_pageview_time) AS pageview_previous_epoch
                FROM {{ source('heap','pageviews') }} p
                -- again want to limit as much strain on memory as possible
                {% if is_incremental() %}
                    WHERE p.heap_user_id IN ( {{ get_active_users('heap_session_start_time') }})
                {% endif %}
            ),
    
    pageviews_delta 
        AS
            (
                -- calculate the delta between pageviews in seconds 
                SELECT 
                    pl.* 
                  , heap_pageview_epoch - pageview_previous_epoch AS pageview_epoch_delta
                FROM pageviews_lag pl 
                ORDER BY pl.heap_user_id, pl.heap_pageview_source, pl.heap_pageview_time
            ), 

    session_start_flag
        AS 
            (
                -- if the time between pageviews is greater than 30 minutes for web or 5 minutes for mobile, mark that pageview row with a 1
                SELECT 
                    pd.* 
                  , CASE
                        WHEN pd.heap_pageview_source = 'web' 
                            THEN (CASE WHEN pd.pageview_epoch_delta > (60 * 30) THEN 1 ELSE 0 END)
                        ELSE 
                            (CASE WHEN pd.pageview_epoch_delta > (60 * 5) THEN 1 ELSE 0 END)
                        END AS heap_session_start_flag 
                FROM pageviews_delta pd 
            ), 
    
    session_index 
        AS 
            (
                -- now we can sum up all of those 1s to get the session sequence number 
                SELECT
                    ss.*
                  , SUM(ss.heap_session_flag) OVER (PARTITION BY ss.heap_user_id, ss.heap_pageview_source ORDER BY ss.heap_pageview_time) AS heap_session_index 
                FROM session_start_flag ss
            ),
    
    sessions_base
        AS 
            (
                -- for every session sequence number, we want info about the last event in that session so that we can join events to sessions based on session start and end timestamps
                SELECT 
                    si.* 
                  , LAST_VALUE(si.heap_pageview_time) OVER (PARTITION BY si.heap_user_id, si.heap_pageview_source, si.heap_session_index ORDER BY si.heap_pageview_time) AS heap_session_end_time
                  , LAST_VALUE(EXTRACT(EPOCH from si.heap_pageview_time)) OVER (PARTITION BY si.heap_user_id, si.heap_pageview_source, si.heap_session_index ORDER BY si.heap_pageview_time) AS heap_session_end_epoch
                  , LAST_VALUE(si.heap_pageview_id) OVER (PARTITION BY si.heap_user_id, si.heap_pageview_source, si.heap_session_index ORDER BY si.heap_pageview_time) AS heap_session_last_pageview_id
                FROM session_index si 
            )
SELECT 
    s.heap_pageview_id 
  , s.heap_user_id
  , s.heap_session_id 
  -- create a session_id concatinating user_id and session sequence number 
  , CONCAT(s.heap_user_id, '_', s.heap_session_index) heap_session_id_new
  , s.heap_session_index
  , s.heap_pageview_source
  , s.heap_pageview_time
-- feature engineering
  , s.pageview_epoch_delta
  , s.session_start_flag
  , s.heap_session_end_time 
  , s.heap_session_end_epoch
  -- look forward session end time based on source of first event in session
  , CASE 
        WHEN s.heap_pageview_source = 'web'
            THEN DATEADD('m', 30, s.heap_session_end_time) 
        ELSE DATEADD('m', 5, s.heap_session_end_time)
        AS heap_session_look_forward
  , s.heap_session_last_pageview_id 
-- pageview props inherited from sessions 
  , s.heap_session_device_type 
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
  , s.heap_session_device_type
  , s.heap_session_carrier 
  , s.heap_session_app_name
  , s.heap_pageview_view_controller 
  , s.heap_pageview_screen_a11y_id
  , s.heap_pageview_screen_a11y_label

FROM sessions_base s

{% else %}

-- if resessionization isnt needed just use the standard pageviews table
SELECT 
    p.heap_pageview_id 
  , p.heap_user_id 
  , p.heap_session_id 
  , p.heap_pageview_time 
  , p.heap_pageview_source 
  , p.heap_session_device_type 
  , p.heap_session_country
  , p.heap_session_region
  , p.heap_session_city 
  , p.heap_session_ip 
  , p.heap_session_referrer 
  , p.heap_session_landing_page
  , p.heap_session_landing_page_query 
  , p.heap_session_landing_page_hash 
  , p.heap_session_browser
  , p.heap_session_utm_source
  , p.heap_session_utm_campaign
  , p.heap_session_utm_medium 
  , p.heap_session_utm_term 
  , p.heap_session_utm_content
  , p.heap_session_device_type
  , p.heap_session_carrier 
  , p.heap_session_app_name
  , p.heap_pageview_view_controller 
  , p.heap_pageview_screen_a11y_id
  , p.heap_pageview_screen_a11y_label


FROM {{ source('heap','pageviews') }} p 

{% if is_incremental() %}
    WHERE p.heap_user_id IN ({{get_active_users('heap_session_start_time')}})
{% endif %}

{% endif %}
