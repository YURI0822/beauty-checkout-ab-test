# 04. 데이터 스키마

## 1. 데이터셋 구성 (BigQuery)

| 데이터셋 | 용도 | 비고 |
|---|---|---|
| raw | 원본 적재 | 생성 데이터를 그대로 적재, 수정하지 않음 | 
| stg | 정제 | 타입 변환 (KST), 중복·이상치 처리, 컬럼명 통일 |
| mart | 분석용 | 세션,퍼널,고객 단위 집계 (정제,마트 단계에서 설계) |

## 2. 데이터 기간 

| 구분 | 기간 | 포함 테이블 |
|---|---|---|
| 월별 KPI | 2025-01 ~ 2026-07 | kpi_monthly |
| 사전 기간 | 2026-06-22 ~ 2026-08-16 (8주) | events, orders, order_items, returns |
| 실험 기간 | 2026-08-24 ~ 2026-09-20 (4주, 실험 설계 후 생성) | events, orders, order_items, returns, experiment_assignment |
| 재구매 관찰 | 2026-09-21 ~ 2026-10-20 (실험 종료 후 30일) | orders, order_items, returns |

- 구체적 날짜는 아래 7장 참고

## 3. 테이블 목록 

| 테이블 | 단위 (1행) | 설명 |
|---|---|---|
| events | 이벤트 1건 | 앱·웹 행동로그 (GA4 형식, 03 이벤트 로깅 설계서 참고) |
| users | 회원 1명 | 회원 기본 정보, 채널별 첫 구매일 |
| products | 상품(옵션) 1개 | 상품 마스터 |
| orders | 주문 1건 | 온라인 주문 |
| order_items | 주문 내 상품 1개 | 주문 상세 |
| returns | 반품 1건 | 반품·교환 내역 |
| kpi_monthly | 월 1개 | 경영 리포트용 월별 KPI 집계 |


## 4. 테이블 상세 

### users 

| 컬럼 | 타입 | 설명 |
|---|---|---|
| user_id | STRING | 회원 ID (PK) |
| signup_date | DATE | 가입일 | 
| signup_channel | STRING | 가입 채널 (`store`,`online`) | 
| membership_grade | STRING | 현재 멤버십 등급 |
| first_store_purchase_date | DATE | 첫 매장 구매일 (없으면 NULL) |
| first_online_purchase_date | DATE | 첫 온라인 구매일 (없으면 NULL) |

- 고객 구분은 이 테이블의 첫 구매일과 기준 시점을 비교해 계산 (위에서부터 순서대로 판단)
  1. 기준 시점 이전에 온라인 구매일 있음 → 온라인 이용 고객 (기존, 매장 구매 여부 무관)
  2. 기준 시점 이전에 매장 구매일만 있음 → 매장 전용 고객 (기존)
  3. 기준 시점 이전에 둘 다 없음 → 신규 고객
- 첫 구매일을 여부(Y/N)가 아닌 날짜로 두는 이유 : 기간 중 첫 구매한 고객은 기준 시점에 따라 구분이 달라지므로

### products 

| 컬럼 | 타입 | 설명 |
|---|---|---|
| item_id | STRING | 상품 ID (PK, 옵션별로 별도 ID) |
| item_name | STRING | 상품명 | 
| item_category | STRING | 카테고리 |
| item_variant | STRING | 옵션 (호수·컬러·용량, 없으면 NULL) |
| option_count | INTEGER | 같은 상품의 옵션 개수 |
| is_mini | BOOLEAN | 소용량·미니 사이즈 여부 |
| price | INTEGER | 판매가 (원) |
| margin_rate | FLOAT | 마진율 (도메인 설정서의 카테고리별 마진율 기준) |

### orders 

| 컬럼 | 타입 | 설명 |
|---|---|---|
| order_id | STRING | 주문 ID (PK, events의 transaction_id와 동일) |
| user_id | STRING | 회원 ID |
| order_datetime | DATETIME | 주문 일시 (KST) |
| platform | STRING | `APP` / `WEB` |
| item_amount | INTEGER | 상품 금액 합계 |
| shipping_fee | INTEGER | 배송비 (3만 원 이상 0, 미만 2,500) |
| total_amount | INTEGER | 결제 금액 (상품 금액 + 배송비) |
| payment_type | STRING | 결제수단 |
| order_status | STRING | `completed`,`cancelled` |


### order_items

| 컬럼 | 타입 | 설명 |
|---|---|---|
| order_id | STRING | 주문 ID |
| item_id | STRING | 상품 ID |
| price | INTEGER | 주문 당시 단가 |
| quantity | INTEGER | 수량 |
| add_source | STRING | 장바구니에 담긴 경로 (`product`,`list`,`cart`) |


### returns

| 컬럼 | 타입 | 설명 |
|---|---|---|
| return_id | STRING | 반품 ID (PK) |
| order_id | STRING | 주문 ID |
| item_id | STRING | 상품 ID |
| return_date | DATE | 반품 접수일 |
| quantity | INTEGER | 반품 수량 |
| refund_amount | INTEGER | 환불 금액 | 
| return_reason | STRING | `option_mismatch` (호수·컬러 불만), `change_of_mind` (단순 변심), `damaged` (파손), `wrong_delivery` (오배송) |

### kpi_monthly

| 컬럼 | 타입 | 설명 |
|---|---|---|
| month | DATE | 월 (매월 1일) |
| new_visitors | INTEGER | 신규 고객 중 해당 월 앱·웹 방문자 수 (첫 구매 전환율의 분모) |
| new_signups | INTEGER | 신규 가입 수 |
| new_buyers | INTEGER | 신규 고객 중 첫 구매 고객 수 |
| new_first_purchase_rate | FLOAT | 신규 첫 구매 전환율 (new_buyers ÷ new_visitors) |
| new_avg_first_order_amount | INTEGER | 신규 첫 주문 평균 금액 |
| existing_buyers | INTEGER | 기존 고객 중 온라인 구매 고객 수 |
| existing_purchase_rate | FLOAT | 기존 고객 온라인 구매 전환율 |
| revenue_new | INTEGER | 신규 고객 온라인 매출 |
| revenue_existing | INTEGER | 기존 고객 온라인 매출 |
| marketing_cost | INTEGER | 마케팅 비용 |

- 경영 리포트에서 가져온 집계 데이터로, 원본(이벤트·주문)과 직접 연결되지 않음
- 고객 구분은 사내 기준(구매 이력 기준)

## 5. 테이블 관계

```
users.user_id ─┬─ events.user_id
               └─ orders.user_id ── orders.order_id ─┬─ order_items.order_id ── products.item_id
                                                    └─ returns.order_id
events (purchase).transaction_id = orders.order_id
```

## 6. 데이터 품질 이슈

- (데이터 생성 후 점검 결과 기록)

## 7. 주요 날짜

| 구분 | 날짜 |
|---|---|
| 무료배송 기준 상향 (2만 → 3만 원) | 2026-01-01 |
| 월별 KPI 범위 | 2025-01 ~ 2026-07 |
| 사전 기간 (8주) | 2026-06-22 (월) ~ 2026-08-16 (일) |
| 분석 요청일 | 2026-08-17 (월) |
| 사전 분석·실험 준비 | 2026-08-17 ~ 2026-08-23 |
| 실험 기간 (4주) | 2026-08-24 (월) ~ 2026-09-20 (일) |
| 재구매 관찰 종료 | 2026-10-20 (화) |

- 실험 기간은 추석 연휴(2026-09-24 ~ 09-27)를 피해 설정함
