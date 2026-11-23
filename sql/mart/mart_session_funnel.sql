# mart.session_funnel: 세션 1행 = 1세션, 퍼널 단계 도달 여부와 장바구니 정보
create or replace table mart.session_funnel as

with s as (                                                        # 1단계: stg.events를 세션 단위로 요약
  select
      session_key
      ,any_value(user_pseudo_id)                                as user_pseudo_id
      ,max(user_id_filled)                                      as user_id          # 세션마다 1개 (보정된 값)
      ,min(event_datetime)                                      as session_start    # 세션 시작 시각 (KST)
      ,date(min(event_datetime))                                as session_dt       # 세션 날짜 = 시작한 날 (자정을 넘겨도 시작일로)
      ,any_value(session_number)                                as session_number   # 이 기기의 몇 번째 세션
      ,any_value(platform)                                      as platform
      ,any_value(traffic_medium)                                as traffic_medium
      ,any_value(campaign)                                      as campaign

      # ── 단계 도달 여부 (한 번이라도 있으면 1) ──
      ,if(countif(event_name = 'view_item') > 0, 1, 0)           as f1_view_item
      ,if(countif(event_name = 'add_to_cart') > 0, 1, 0)         as f2_add_to_cart
      ,if(countif(event_name = 'view_cart') > 0, 1, 0)           as f3_view_cart
      ,if(countif(event_name = 'begin_checkout') > 0, 1, 0)      as f4_begin_checkout
      ,if(countif(event_name = 'add_shipping_info') > 0, 1, 0)   as f5_add_shipping
      ,if(countif(event_name = 'add_payment_info') > 0, 1, 0)    as f6_add_payment
      ,if(countif(event_name = 'purchase') > 0, 1, 0)            as f7_purchase

      # ── 장바구니 (세션의 마지막 view_cart 기준) ──
      ,array_agg(if(event_name = 'view_cart', value, null) ignore nulls
                 order by event_timestamp desc limit 1)[safe_offset(0)]                   as last_cart_value         # 장바구니 금액
      ,array_agg(if(event_name = 'view_cart', free_shipping_remaining, null) ignore nulls
                 order by event_timestamp desc limit 1)[safe_offset(0)]                   as last_free_ship_remaining  # 무료배송까지 남은 금액
      ,countif(event_name = 'view_cart')                         as n_view_cart
      ,countif(event_name = 'click_continue_shopping')           as n_continue_shopping   # 장바구니에서 더 담으러 나간 횟수
      ,countif(event_name = 'add_to_cart')                       as n_add_to_cart

      # ── 구매 ──
      ,max(transaction_id)                                       as transaction_id   # = orders.order_id (구매 없으면 null)
      ,sum(purchase_revenue)                                     as purchase_revenue
    from stg.events
   group by 1
)

select                                                             # 2단계: 세션 날짜 기준 고객 유형
    s.*
    ,case
       when u.first_online_purchase_date < s.session_dt then '온라인 이용'
       when u.first_store_purchase_date  < s.session_dt then '매장 전용'
       else '신규'
     end                                                         as customer_type
  from s
  left
  join raw.users u
    on s.user_id = u.user_id
 where 1=1
   and s.session_dt between '2026-06-22' and '2026-08-16'          # 분석 기간 (시작일 기준, 8/17 0시 이벤트는 전날 세션에 포함)