create or replace table stg.order_items as 
SELECT 
    oi.order_id 
    ,oi.item_id 
    ,max(oi.price)              as price  # 같은 주문 및 상품이면 주문 단가는 같음 
    ,sum(oi.quantity)           as quantity   # 경로별 수량 합산
    ,sum(oi.price * oi.quantity)  as item_amount  # 상품 금액
    ,string_agg(oi.add_source, ',' order by oi.add_source)  as add_sources   # ex. 'list,product'
    ,any_value(p.item_category)   as item_category
    ,any_value(p.margin_rate)   as margin_rate
  from raw.order_items oi
  left
  join raw.products p 
    on oi.item_id = p.item_id 
 group 
    by 1,2
