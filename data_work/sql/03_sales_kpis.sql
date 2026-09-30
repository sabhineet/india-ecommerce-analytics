-- =====================================================================
-- 03_sales_kpis.sql
-- Project : India E-Commerce Sales & Profitability Analytics
-- Purpose : Overall KPIs, monthly trend, and target vs actual.
-- Source  : clean_sales_lines, clean_sales_target (see 02_cleaning.sql)
-- Definitions used everywhere:
--   Revenue = SUM(amount)   Profit = SUM(profit)   Units = SUM(quantity)
--   Orders  = COUNT(DISTINCT order_id)   (NOT COUNT(*), which counts lines)
--   AOV     = Revenue / Orders
--   Profit margin = Profit / Revenue
-- Assumption: the source does not say whether Amount is before/after
--   discounts, tax or returns. It is called "revenue (Amount)" in this project.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1: KPI summary   (feeds the Tableau KPI cards)
-- Question: How big is the business, and how profitable?
-- Why: SAFE_DIVIDE returns NULL instead of an error if the denominator is 0.
-- Expected: revenue 431502 | profit 23955 | profit_margin ~0.0555 |
--           orders 500 | units 5615 | avg_order_value 863.004 | customers 399
-- Note: customers is based on the DERIVED customer_key (name + state).
-- ---------------------------------------------------------------------
SELECT
  SUM(amount) AS revenue,
  SUM(profit) AS profit,
  SAFE_DIVIDE(SUM(profit), SUM(amount)) AS profit_margin,
  COUNT(DISTINCT order_id) AS orders,
  SUM(quantity) AS units,
  SAFE_DIVIDE(SUM(amount), COUNT(DISTINCT order_id)) AS avg_order_value,
  COUNT(DISTINCT customer_key) AS customers
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`;


-- ---------------------------------------------------------------------
-- Q2: Monthly revenue and profit with month-over-month growth
--     (feeds the Tableau monthly trend chart)
-- Question: How do revenue and profit move month to month?
-- Why: aggregate to ONE ROW PER MONTH first (CTE), then use the window
--      function LAG() to read the previous month's revenue without a self-join.
--      The first month has no previous month, so its growth is NULL.
-- Expected: 12 rows. First row Apr-18: revenue 32726, profit -3960,
--           orders 44, revenue_mom_growth NULL. The orders column sums to 500.
-- ---------------------------------------------------------------------
WITH monthly AS (
  SELECT
    order_month,
    SUM(amount) AS revenue,
    SUM(profit) AS profit,
    COUNT(DISTINCT order_id) AS orders,
    SUM(quantity) AS units
  FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
  GROUP BY order_month
)
SELECT
  order_month,
  revenue,
  profit,
  orders,
  units,
  SAFE_DIVIDE(profit, revenue) AS profit_margin,
  SAFE_DIVIDE(
    revenue - LAG(revenue) OVER (ORDER BY order_month),
    LAG(revenue) OVER (ORDER BY order_month)
  ) AS revenue_mom_growth
FROM monthly
ORDER BY order_month;


-- ---------------------------------------------------------------------
-- Q3: Target vs actual by category and month
--     (feeds the Tableau target-attainment chart)
-- Question: Which categories hit their monthly sales targets?
-- Rules: 1) Aggregate BEFORE joining, so both sides are one row per
--           month x category and the join cannot multiply rows.
--        2) LEFT JOIN from the target table, so a month with zero sales
--           still appears (as 0) instead of disappearing.
-- Assumption: targets are compared against Amount (revenue).
-- Expected: 36 rows. SUM(target_amount) = 435900, SUM(actual_revenue) = 431502.
--           16 of the 36 category-months have hit_target = TRUE.
--           Apr-18 check: Furniture 8121 vs 10400 (missed),
--                         Clothing 13478 vs 12000 (hit),
--                         Electronics 11127 vs 9000 (hit).
-- ---------------------------------------------------------------------
WITH actual AS (
  SELECT
    order_month AS target_month,
    category,
    SUM(amount) AS actual_revenue
  FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
  GROUP BY order_month, category
)
SELECT
  t.target_month,
  t.category,
  t.target_amount,
  COALESCE(a.actual_revenue, 0) AS actual_revenue,
  SAFE_DIVIDE(COALESCE(a.actual_revenue, 0), t.target_amount) AS attainment,
  COALESCE(a.actual_revenue, 0) >= t.target_amount AS hit_target
FROM `india-ecommerce-analytics.ecommerce.clean_sales_target` t
LEFT JOIN actual a
  ON a.target_month = t.target_month
 AND a.category = t.category
ORDER BY t.category, t.target_month;
