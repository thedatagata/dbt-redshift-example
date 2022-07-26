
-- this model is an incremental build and will create a table so we need to set the sort and dist keys 
{{
    config(
        sort = 'heap_event_time',
        dist = 'heap_event_id',
        unique_key = 'heap_event_id'
    )
}}


WITH 
    funnel_event_sources
        AS 
            (
                {{get_funnel_event_sources()}}
            )

SELECT 
  e.heap_event_id 
, e.heap_user_id 
, e.heap_session_id 
, e.heap_event_name 
, e.heap_event_time 
, fes.heap_event_source 
-- this will set the funnel position number based on the funnel_events variable set in the dbt_project file 
-- this will allow us to pivot out on sessions to see how far through a funnel a user got for each session
, {{check_funnel_position('e.heap_event_name')}} as heap_event_funnel_position 
-- this will mark if the event is a conversion event so that we can know during which sessions the user converted 
, e.heap_event_name IN {{ gen_conversion_events() }} as heap_is_conversion_event

FROM {{ ref('src_heap_events_eph') }} e
LEFT JOIN funnel_event_sources fes 
    ON fes.heap_funnel_event_name = e.heap_event_name