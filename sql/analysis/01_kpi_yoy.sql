--  SELECT * FROM raw.kpi_monthly order by month;

with monthly_ytd as (
    SELECT 
      month,
      -- LAG(revenue_new,12) over (order by month) as revenue_new_ly,
      revenue_new as r_new,
      -- LAG(revenue_existing,12) over (order by month) as revenue_existing_ly,
      revenue_existing as r_ext,
      sum(revenue_new) over (partition by extract(year from month) order by month ) r_new_ytd,
      sum(revenue_existing) over (partition by extract(year from month) order by month) r_ext_ytd
    FROM raw.kpi_monthly
),
with_last_year as (
  SELECT
    month,
    LAG(r_new,12) over (order by month) as r_new_ly,
    r_new,
    LAG(r_ext,12) over (order by month) as r_ext_ly,
    r_ext,
    LAG(r_new_ytd,12) over (order by month) as r_new_ytd_ly,
    r_new_ytd,
    LAG(r_ext_ytd,12) over (order by month) as r_ext_ytd_ly,
    r_ext_ytd,
  from monthly_ytd
 where 
  1=1
)

select 
  month,
  r_new_ly as `신규 매출 2025`,
  r_new as `신규 매출 2026`,
  round((SAFE_DIVIDE(r_new,r_new_ly)-1)*100,2) as `신규 매출 Uplift`,
  r_new_ytd_ly as `신규 누적 매출 2025`,
  r_new_ytd as `신규 누적 매출 2026`,
  round((SAFE_DIVIDE(r_new_ytd,r_new_ytd_ly)-1)*100,2) as `신규 누적 매출 Uplift`,
  r_ext_ly as `기존 매출 2025`,
  r_ext as `기존 매출 2026`,
  round((SAFE_DIVIDE(r_ext,r_ext_ly)-1)*100,2) as `기존 매출 Uplift`,
  r_ext_ytd_ly as `기존 누적 매출 2025`,
  r_ext_ytd as `기존 누적 매출 2026`,
  round((SAFE_DIVIDE(r_ext_ytd,r_ext_ytd_ly)-1)*100,2) as `기존 누적 매출 Uplift`,
  from with_last_year
 where 1=1
   and month >= '2026-01-01'




