
-- if dbt_project gen_new_sessions variable set to true then we create a sessions table using the pageviews table that created the custom session_id 
{% if var('gen_new_sessions') %} 

    SELECT
        p.heap_session_id_new as heap_session_id 
      , p.heap_user_id  
      , p.heap_session_index
      , p.heap_pageview_time as heap_session_start_time
      , p.heap_session_end_time 
      , p.heap_session_look_forward
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
    
    FROM {{ ref('src_heap_pageviews_eph') }} p 
    WHERE p.heap_session_start_flag = 1
    ORDER BY p.heap_user_id, p.heap_session_index

{% else %}

-- if not creating new session_ids, we still want to have info about the last pageview for each session 
    WITH 
      pageviews 
        AS 
          (
            SELECT 
                p.heap_user_id 
              , p.heap_session_id
              -- grab the greatest pageview timestamp associated with each session id 
              , MAX(p.heap_pageview_time) as heap_session_end_time 
            FROM {{ ref('src_heap_pageviews_eph') }} p 
            GROUP BY 1,2 
          )


    SELECT
        s.heap_session_id 
      , s.heap_user_id 
      -- get the session sequence number so that there is parity between models independent of custom sessions
      , ROW_NUMBER() OVER(PARTITION BY s.heap_user_id, s.heap_session_id ORDER BY s.heap_session_start_time) AS heap_session_index
      , s.heap_session_start_time
      , p.heap_session_end_time
      -- create session look forward window so that there is parity between models independent of custom sessions
      , CASE 
          WHEN s.heap_session_source = 'web'
            THEN DATEADD('m', 30, p.heap_session_end_time) 
          ELSE DATEADD('m', 5, p.heap_session_end_time)
          END AS heap_session_look_forward 
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
      
    
    FROM {{ source('heap','sessions') }} s
    JOIN pageviews p 
      ON s.heap_user_id = p.heap_user_id 
      AND s.heap_session_id = p.heap_session_id 
    ORDER BY s.heap_user_id, s.heap_session_index 
{% endif %}




