# 03. 이벤트 로깅 설계서

## 1. 개요
| 항목 | 내용 |
|---|---|
| 수집 범위 | 앱·모바일 웹의 회원 행동 |
| 저장 형식 | GA4 BigQuery 내보내기 형식 (1행 = 1이벤트, 속성은 중첩 구조 ) |
| 이벤트 명명 규칙 | 영어 소문자 + 언더스코어(snake_case), `동사_대상` 순서 |
| 기준 | GA4 표준 전자상거래 이벤트 우선 사용, 필요한 행동만 사용자 정의 이벤트로 추가 |

## 2. 공통 필드 (모든 이벤트에 존재)
| 필드 | 타입 | 설명 |
|---|---|---|
| event_date | STRING | 이벤트 발생일 (YYYYMMDD, KST기준) |
| event_timestamp | INTEGER | 발생 시각 (마이크로초, UTC기준) |
| event_name | STRING | 이벤트 이름 | 
| user_id | STRING | 회원 ID (로그인 상태에서만 존재) |
| user_pseudo_id | STRING | 기기 식별자 |
| platform | STRING | `APP`/`WEB` |
| device.operating_system | STRING | `iOS`/`Android` 등 |
| traffic_source.source / medium / name | STRING | 최초 유입 경로 (광고매체, 캠페인명) |
| user_properties | ARRAY | 회원 속성 (아래4장) |
| event_params | ARRAY | 이벤트별 속성 (key-value) |
| items | ARRAY | 상품 정보 (전자상거래 이벤트에만 존재) |
| ecommerce | STRUCT | 주문 금액 정보 (전자상거래 이벤트에만 존재) |

- 원본은 GA4 내보내기 형식을 그대로 유지하고, 정제 단계에서 DATE·DATETIME(KST)으로 변환함 추가

### 공통 event_params 

| key | 타입 | 설명 |
|---|---|---|
| ga_session_id | int | 세션 ID |
| ga_session_number | int | 해당 기기의 몇 번째 세션인지 |
| screen_name | string | 현재 화면 (`home`,`search`,`category`,`product`,`cart`,`checkout`, `order_complete`) |
| previous_screen_name | string | 직전 화면 |


### items 배열 구조 

| 필드 | 타입 | 설명 |
|---|---|---|
| item_id | STRING | 상품 ID |
| item_name | STRING | 상품명 |
| item_category | STRING | 카테고리 |
| item_variant | STRING | 옵션(호수·컬러·용량) |
| price | FLOAT | 단가 |
| quantity | INTEGER | 수량 |

## 3. 이벤트 목록 

### 3-1. 세션·회원

| 이벤트 | 발생 시점 | 주요 event_params |
|---|---|---|
| session_start | 앱 실행 또는 웹 접속시 세션 시작 | - |
| sign_up | 온라인 회원가입 완료 | method (`kakao`,`naver`,`email`) |
| login | 로그인 완료 | method |
| screen_view | 화면 진입 | screen_name, previous_screen_name |

### 3-2. 탐색
| 이벤트 | 발생 시점 | 주요 event_params / items |
|---|---|---|
| search | 검색어 입력 후 검색 실행 | search_term, result_count |
| view_item_list | 상품 목록 노출 (검색결과,카테고리) | item_list_name, items |
| select_item | 목록에서 상품 선택 | item_list_name, items |
| view_item | 상품 상세 진입 | items, value |

### 3-3. 상품 상세 (옵션,리뷰)

| 이벤트 | 발생 시점 | 주요 event_params |
|---|---|---|
| open_option_selector | 옵션(호수·컬러·용량) 선택창 열림 | item_id, option_count |
| select_option | 옵션 선택 | item_id, item_variant |
| view_review | 리뷰 탭 진입 | item_id |
| search_review | 리뷰 내 키워드 검색 | item_id, search_term |

### 3-4. 장바구니 

| 이벤트 | 발생 시점 | 주요 event_params / items |
|---|---|---|
| add_to_cart | 장바구니 담기 | items, value, add_source (`product`, `list`, `cart`) |
| remove_from_cart | 장바구니에서 상품 삭제 | items, value |
| view_cart | 장바구니 화면 진입 | value (장바구니 금액), free_shipping_remaining (무료배송까지 남은 금액, 기준 이상이면 0), item_count |
| click_continue_shopping | 장바구니에서 '쇼핑 계속하기' 클릭 | value, free_shipping_remaining |


### 3-5. 주문·결제

| 이벤트 | 발생 시점 | 주요 event_params / ecommerce |
|---|---|---|
| begin_checkout | 장바구니에서 '구매하기' 클릭, 주문서 진입 | value, shipping (배송비), items |
| add_shipping_info | 배송지 입력·확인 완료 | shipping_saved (저장된 배송지 사용 여부) |
| add_payment_info | 결제수단 선택 완료 | payment_type |
| purchase | 결제 완료 | transaction_id, value, shipping, items |


## 4. user_properties

| key | 설명 |
|---|---|
| membership_grade | 멤버십 등급 (`pearl`, `gold`, `diamond`, `black_diamond`) |
| signup_channel | 가입 채널 (`store`, `online`) |

- 고객 구분(기존/신규)은 로그에 넣지 않음 → 회원·주문 데이터로 계산 (사내 기준이 바뀌어도 로그를 다시 쌓을 필요가 없도록)

## 5. 이벤트 간 관계 (구매 퍼널)

```
session_start
 → search / view_item_list → select_item
 → view_item (→ open_option_selector → select_option, view_review)
 → add_to_cart
 → view_cart (→ click_continue_shopping → 탐색으로 복귀)
 → begin_checkout → add_shipping_info → add_payment_info
 → purchase
```

## 6. 실험용 이벤트

- 실험 설계 단계에서 추가 (장바구니 추천 영역 노출·클릭·담기)