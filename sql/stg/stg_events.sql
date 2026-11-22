# stg.events: 분석용으로 정리한 이벤트 로그 (1행 = 1이벤트)
# ★ 표시한 두 곳이 품질 점검 3번·4번을 반영한 부분
create or replace table stg.events as

with base as (                                                     # 1단계: 컬럼 정리
  select
      # ── 날짜·시각 (raw는 event_date=KST 문자열, event_timestamp=UTC 마이크로초) ──
      parse_date('%Y%m%d', event_date)                            as event_dt          # 이벤트 날짜 (KST)
      ,datetime(timestamp_micros(event_timestamp), 'Asia/Seoul')  as event_datetime    # 이벤트 시각 (KST)
      ,event_timestamp                                                                 # 세션 안 순서 정렬용으로 원본도 남김
      ,event_name

      # ── 사람·세션 ──
      ,user_pseudo_id                                                                  # 기기
      ,user_id                                                                         # 원래 값 (로그인 시점 분석용으로 남김)
      ,(select value.int_value from unnest(event_params) where key = 'ga_session_id')     as session_id
      ,(select value.int_value from unnest(event_params) where key = 'ga_session_number') as session_number   # 이 기기의 몇 번째 세션
      ,platform
      ,device.operating_system                                    as os
      ,traffic_source.source                                      as traffic_source
      ,traffic_source.medium                                      as traffic_medium
      ,traffic_source.name                                        as campaign

      # ── 화면 (모든 이벤트 공통) ──
      ,(select value.string_value from unnest(event_params) where key = 'screen_name')          as screen_name
      ,(select value.string_value from unnest(event_params) where key = 'previous_screen_name') as previous_screen_name

      # ── 이벤트별 속성 (해당 이벤트에만 값이 있고 나머지는 null) ──
      ,(select coalesce(value.double_value, cast(value.int_value as float64))
          from unnest(event_params) where key = 'value')                    as value                    # 금액 (상품, 장바구니 등)
      ,(select coalesce(value.int_value, cast(value.double_value as int64))
          from unnest(event_params) where key = 'free_shipping_remaining')  as free_shipping_remaining  # view_cart·click_continue_shopping
      ,(select value.int_value    from unnest(event_params) where key = 'item_count')     as item_count       # view_cart
      ,(select coalesce(value.double_value, cast(value.int_value as float64))
          from unnest(event_params) where key = 'shipping')                 as shipping                 # begin_checkout·purchase 배송비
      ,(select value.string_value from unnest(event_params) where key = 'add_source')     as add_source       # 담은 화면은 이 값으로 판단
      ,(select value.string_value from unnest(event_params) where key = 'item_list_name') as item_list_name
      ,(select value.string_value from unnest(event_params) where key = 'item_id')        as item_id          # 옵션·리뷰 이벤트
      ,(select value.int_value    from unnest(event_params) where key = 'option_count')   as option_count
      ,(select value.string_value from unnest(event_params) where key = 'item_variant')   as item_variant
      ,(select value.string_value from unnest(event_params) where key = 'search_term')    as search_term
      ,(select value.int_value    from unnest(event_params) where key = 'result_count')   as result_count
      ,(select value.string_value from unnest(event_params) where key = 'method')         as method           # login·sign_up
      ,(select value.string_value from unnest(event_params) where key = 'payment_type')   as payment_type
      ,(select value.string_value from unnest(event_params) where key = 'shipping_saved') as shipping_saved

      # ── 주문 (purchase에만) ──
      ,ecommerce.transaction_id                                   as transaction_id    # = orders.order_id
      ,ecommerce.purchase_revenue                                 as purchase_revenue

      # ── 상품 배열은 그대로 (상품 단위 분석 때 unnest) ──
      ,items
    from raw.events
),

filled as (                                                        # 2단계: ★ user_id 채우기
  select
      *
      ,concat(user_pseudo_id, '-', cast(session_id as string))   as session_key       # 세션을 한 컬럼으로 (조인·count distinct용)
      ,coalesce(user_id
               ,max(user_id) over (partition by user_pseudo_id, session_id))     as user_id_filled    # 없으면 같은 세션의 user_id (세션마다 1개뿐)
    from base
)

select                                                             # 3단계: ★ purchase 중복 제거
    *
  from filled
qualify
    event_name != 'purchase'                                       # purchase가 아닌 이벤트는 모두 남김
    or row_number() over (partition by transaction_id order by event_timestamp) = 1   # purchase는 주문 번호마다 첫 1건만