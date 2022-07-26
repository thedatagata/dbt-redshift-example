
{{
    config(
        sort = 'heap_user_last_updated',
        dist = 'heap_user_id',
        unique_key = 'heap_user_id'
    )
}}


WITH 
    funnel_rollup
        AS 
            (
                SELECT
                    s.heap_user_id, 
                    {{ gen_user_funnel_rollup() }}
                    SUM(s.heap_session_conversion) AS heap_user_registration_cnt

                FROM {{ ref('stg_heap_sessions_fct') }} s
                {% if is_incremental() %}
                  WHERE s.heap_user_id IN ({{get_active_users('heap_user_last_updated')}})
                {% endif %}
                GROUP BY 1 
            )


SELECT 
    u.heap_user_id
  , u.heap_user_first_session_time
  , u.heap_user_last_updated
  , u.drf_user_id
  , u.drf_user_email
  , u.drf_bets_id
  , u.drf_bets_approved
  , u.drf_signup_type
  , f.* 

FROM {{ ref('src_heap_users_eph') }} u 
LEFT JOIN funnel_rollup f
  ON u.heap_user_id = f.heap_user_id