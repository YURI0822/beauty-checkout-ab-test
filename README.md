# 데일리글로우 신규 고객 첫 구매 전환 개선 (BigQuery · A/B 테스트)

가상 H&B(헬스 & 뷰티) 옴니채널 플랫폼 **'데일리글로우(DAILY GLOW)'** 의 하반기 온라인 매출 목표 미달 문제를 데이터로 진단하고, 개선 과제를 A/B 테스트로 검증하는 포트폴리오 프로젝트임

- 데이터: 시드 고정 가상 데이터 (GA4 BigQuery 내보내기 형식 이벤트 로그 + 주문·회원·상품·반품 + 월별 KPI)
- 환경: BigQuery (원본 → 정제 → 마트), Python (데이터 생성, 통계 검정, 시각화), Looker Studio (대시보드)

## 1. 배경

| 항목 | 내용 |
|---|---|
| 연간 목표 | 온라인 매출 전년 대비 +18% (기존 고객 기여 +11%p + 신규 고객 기여 +7%p, 신규 매출 약 +47% 성장 전제) |
| 상반기 실적 | +10%로 미달 → 하반기 목표를 +25%로 상향, 신규 고객 확보 마케팅 +40% 투입 |
| 현황 (2026년 7월) | +12%로 목표 미달 |
| 문제 제기 | 신규 고객 매출 달성률 60% (기존 고객 97%), 마케팅 비용은 전년 대비 +40% |
| 요청 | 신규 고객 매출 미달 원인 파악 → 개선 과제 1개 선정 → 효과 검증 |

- 자세한 내용: [도메인 설정서](docs/01_domain_setting.md), [분석 요청서](docs/02_business_brief.md)

## 2. 진행 단계

| 단계 | 내용 | 산출물 | 상태 |
|---|---|---|---|
| 1. 기획 | 도메인 설정, 분석 요청서 | `docs/01`, `docs/02` | 완료 |
| 2. 데이터 설계 | 이벤트 로깅 설계 (GA4 형식), 테이블 스키마 | `docs/03`, `docs/04` | 완료 |
| 3. 환경 준비 | BigQuery 프로젝트·데이터셋, Python 연결 | `notebooks/00_setup_check.ipynb` | 완료 |
| 4. 데이터 생성·적재 | 사전 기간 8주 데이터 생성 → BigQuery `raw` 적재 | `notebooks/01_generate_data.ipynb` | 완료 |
| 5. 품질 점검 | 날짜 누락, 키 중복, user_id 결측, 구매 정합성, 이벤트 속성 점검 | `notebooks/02_quality_check.ipynb` | 완료 |
| 6. 정제·마트 | 원본 → 정제(stg) → 마트(mart) SQL | `sql/stg/`, `sql/mart/`, `notebooks/04_build_stg.ipynb` | 완료 |
| 7. 사전 분석 | KPI 트리, 퍼널, 이슈 발견, 우선순위 | `docs/05_background_analysis.md`, `notebooks/03_background_analysis.ipynb`, `notebooks/05_funnel_analysis.ipynb` | 진행 중 (월별 KPI 분석 완료, 퍼널 분석 진행 중) |
| 8. 실험 설계 | 가설, 지표, 표본 크기 | `docs/06_experiment_design.md` | 진행 예정 |
| 9. 실험 분석 | A/B 결과, 세그먼트, 공헌이익 | `notebooks/` | 진행 예정 |
| 10. 대시보드·보고 | Looker Studio, 경영진 1페이지 요약 | — | 진행 예정 |

## 3. 리포지토리 구조

```
├── README.md
├── config.py            # 프로젝트 공통 설정 (BigQuery 프로젝트 ID, 리전, 시드)
├── docs/                # 분석가 시점 문서 (설계서, 분석 결과)
├── answer/              # 데이터에 심은 정답 (분석 후 대조용)
├── sql/
│   ├── analysis/        # 월별 KPI 분석 (전년 대비, 기여도, 신규 매출 분해)
│   ├── stg/             # 정제 테이블 생성 (events, orders, order_items)
│   └── mart/            # 분석용 마트 (세션 퍼널)
├── notebooks/           # 00 환경 확인, 01 데이터 생성, 02 품질 점검, 03 배경 분석, 04 정제·마트 생성, 05 퍼널 분석
└── data/                # 생성 데이터 백업 (events는 용량 문제로 제외, 시드로 재생성)
```

### 문서 구분

| 폴더 | 성격 |
|---|---|
| `docs/` | 분석가가 알고 있는 정보와 분석 결과. 원인은 데이터에서 직접 찾아냄 |
| `answer/` | 데이터를 만들 때 심어둔 이슈·효과 (정답). **분석가는 이 문서를 보지 않고 분석함** |

## 4. 데이터

| 테이블 | 행 수 | 설명 |
|---|---|---|
| events | 4,390,472 | 앱·웹 행동 로그 (GA4 형식, 중첩 구조) |
| users | 100,000 | 회원, 채널별 첫 구매일 |
| products | 587 | 상품 (옵션별 ID) |
| orders | 51,523 | 온라인 주문 |
| order_items | 144,768 | 주문 상세 |
| returns | 5,370 | 반품 |
| kpi_monthly | 19 | 경영 리포트 월별 KPI (2025-01 ~ 2026-07) |

- 사전 기간: 2026-06-22 ~ 2026-08-16 (8주)

### 정제(stg)·마트(mart)

| 테이블 | 행 수 | 내용 |
|---|---|---|
| stg.events | 4,390,060 | KST 날짜·시각, event_params를 컬럼으로 펼침, user_id 결측 보정(`user_id_filled`), purchase 중복 제거 |
| stg.orders | 51,523 | 주문일, 무료배송 여부, 주문 시점 고객 유형(신규·매장 전용·온라인 이용) |
| stg.order_items | 144,760 | 주문+상품 단위로 수량 합산, 담은 경로·카테고리·마진율 |
| mart.session_funnel | 344,287 | 세션 1행: 퍼널 단계 도달 여부, 마지막 장바구니 금액·무료배송까지 남은 금액, 고객 유형 |

### 데이터 품질 점검 요약

| 점검 | 결과 | 정제에서 한 처리 |
|---|---|---|
| 날짜 누락 | 문제 없음 | 분석 기간은 세션 시작일 기준 6/22~8/16 |
| 키 중복 | order_items 8쌍은 담은 경로만 다른 정상 행 | 상품 단위 분석 시 수량 합산 |
| user_id 결측 | 9.6%, 로그인 전 이벤트에서 발생, 신규 고객에 몰림 | 같은 세션의 user_id로 100% 보정 |
| 구매 정합성 | purchase 이벤트 0.79% 전송 중복 | 주문 번호마다 첫 이벤트만 남김 → orders와 완전 일치 |
| 이벤트 속성 | 문제 없음 (remove_from_cart는 로깅되지 않음) | 담은 화면은 add_source로 판단 |
- 구조: [데이터 스키마](docs/04_data_schema.md), [이벤트 로깅 설계서](docs/03_event_logging_spec.md)

## 5. 재현 방법

1. Google Cloud 프로젝트 생성 후 BigQuery 데이터셋 `raw`, `stg`, `mart` 생성 (리전: `asia-northeast3`)
2. `config.py`의 `PROJECT_ID`를 본인 프로젝트 ID로 변경
3. `notebooks/`의 노트북을 번호 순서대로 실행
   - `01_generate_data.ipynb`가 시드 42로 동일한 데이터를 생성하고 `raw`에 적재함
   - `04_build_stg.ipynb`가 `sql/stg/`, `sql/mart/`의 SQL을 실행해 정제·마트 테이블을 만듦 (stg → mart 순서)
