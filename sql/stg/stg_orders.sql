# stg.orders: 주문 1행 = 1주문, 주문 시점 고객 유형을 붙임
create or replace table stg.orders as
select
    o.order_id
    ,o.user_id
    ,o.order_datetime                                            # 주문 시각 (이미 KST)
    ,date(o.order_datetime)                    as order_dt       # 주문일
    ,o.platform
    ,o.item_amount
    ,o.shipping_fee
    ,o.total_amount
    ,o.payment_type
    ,o.order_status
    ,o.item_amount >= 30000                    as is_free_shipping   # 3만 원 이상이면 true
    ,case                                                        # 주문일 "이전" 구매 이력으로 판단 (온라인 → 매장 → 신규 순서)
       when u.first_online_purchase_date < date(o.order_datetime) then '온라인 이용'
       when u.first_store_purchase_date  < date(o.order_datetime) then '매장 전용'
       else '신규'
     end                                       as customer_type
  from raw.orders o
  left
  join raw.users u
    on o.user_id = u.user_id