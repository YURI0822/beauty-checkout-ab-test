-- 02. 성장 기여도: 1~N월 누적 전체 성장률을 기존 고객 몫과 신규 고객 몫(%p)으로 나눔
-- 기여도(%p) = (올해 누적 - 전년 누적) ÷ 전년 "전체" 누적 매출 × 100
-- 두 기여도를 더하면 전체 성장률과 정확히 같아짐 (그냥 성장률을 더하면 비중이 반영되지 않아 틀림)

WITH monthly_ytd AS (
  -- 1단계: 연도별 1월부터 해당 월까지 누적 매출
  SELECT
    month,
    SUM(revenue_existing) OVER (PARTITION BY EXTRACT(YEAR FROM month) ORDER BY month) AS r_ext_ytd,  -- 기존 고객 누적
    SUM(revenue_new)      OVER (PARTITION BY EXTRACT(YEAR FROM month) ORDER BY month) AS r_new_ytd   -- 신규 고객 누적
  FROM raw.kpi_monthly
),
with_last_year AS (
  -- 2단계: 같은 월의 전년 누적 매출을 옆에 붙임 (12행 전 = 전년 동월)
  SELECT
    month,
    r_ext_ytd,
    r_new_ytd,
    LAG(r_ext_ytd, 12) OVER (ORDER BY month) AS r_ext_ytd_ly,
    LAG(r_new_ytd, 12) OVER (ORDER BY month) AS r_new_ytd_ly
  FROM monthly_ytd
)
-- 3단계: 전체 성장률과 고객 유형별 기여도
SELECT
  month,
  ROUND(SAFE_DIVIDE(r_ext_ytd + r_new_ytd, r_ext_ytd_ly + r_new_ytd_ly) * 100 - 100, 2) AS total_growth_pct,      -- 전체 누적 성장률 (%)
  ROUND(SAFE_DIVIDE(r_ext_ytd - r_ext_ytd_ly, r_ext_ytd_ly + r_new_ytd_ly) * 100, 2)   AS existing_contrib_pp,   -- 기존 고객 기여 (%p)
  ROUND(SAFE_DIVIDE(r_new_ytd - r_new_ytd_ly, r_ext_ytd_ly + r_new_ytd_ly) * 100, 2)   AS new_contrib_pp,        -- 신규 고객 기여 (%p)
  ROUND(SAFE_DIVIDE(r_new_ytd_ly, r_ext_ytd_ly + r_new_ytd_ly) * 100, 1)               AS new_share_ly_pct       -- 전년 누적 매출 중 신규 비중 (%)
FROM with_last_year
WHERE month >= '2026-01-01'
ORDER BY month
