-- 03. 신규 매출 분해: 신규 매출 = 신규 방문 고객 수 × 첫 구매 전환율 × 첫 주문 평균 금액
-- 세 요소의 전년 동월 대비 변화를 보고, 로그로 바꿔 각 요소가 신규 매출 변화에 얼마나 기여했는지 나눔
--   LN(매출 배수) = LN(방문 배수) + LN(전환율 배수) + LN(주문 금액 배수)  ← 곱셈이 덧셈으로 바뀌어 합이 정확히 맞음
--   로그 값 × 100은 변화율(%)과 비슷한 크기로 읽으면 됨 (예: 0.10 ≈ +10%)

WITH with_last_year AS (
  SELECT
    month,
    new_visitors,
    -- 전환율은 반올림된 new_first_purchase_rate 대신 구매자 ÷ 방문자로 다시 계산 (반올림 오차 때문에 곱셈 관계가 어긋나지 않도록)
    SAFE_DIVIDE(new_buyers, new_visitors) AS conv_rate,
    new_avg_first_order_amount              AS aov,
    revenue_new,
    LAG(new_visitors, 12)                              OVER (ORDER BY month) AS new_visitors_ly,
    LAG(SAFE_DIVIDE(new_buyers, new_visitors), 12)     OVER (ORDER BY month) AS conv_rate_ly,
    LAG(new_avg_first_order_amount, 12)                OVER (ORDER BY month) AS aov_ly,
    LAG(revenue_new, 12)                               OVER (ORDER BY month) AS revenue_new_ly
  FROM raw.kpi_monthly
)
SELECT
  month,
  -- 요소별 전년 대비 변화율 (%)
  ROUND((SAFE_DIVIDE(new_visitors, new_visitors_ly) - 1) * 100, 2) AS visitors_yoy_pct,
  ROUND((SAFE_DIVIDE(conv_rate, conv_rate_ly) - 1) * 100, 2)       AS conv_rate_yoy_pct,
  ROUND((SAFE_DIVIDE(aov, aov_ly) - 1) * 100, 2)                   AS aov_yoy_pct,
  ROUND((SAFE_DIVIDE(revenue_new, revenue_new_ly) - 1) * 100, 2)   AS revenue_new_yoy_pct,
  -- 로그 분해 (세 요소의 합 = 신규 매출)
  ROUND(LN(SAFE_DIVIDE(new_visitors, new_visitors_ly)), 4)         AS ln_visitors,
  ROUND(LN(SAFE_DIVIDE(conv_rate, conv_rate_ly)), 4)               AS ln_conv_rate,
  ROUND(LN(SAFE_DIVIDE(aov, aov_ly)), 4)                           AS ln_aov,
  ROUND(LN(SAFE_DIVIDE(revenue_new, revenue_new_ly)), 4)           AS ln_revenue_new
FROM with_last_year
WHERE month >= '2026-01-01'
ORDER BY month
