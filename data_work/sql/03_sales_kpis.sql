-- =====================================================================
-- 03_sales_kpis.sql
-- India E-Commerce Sales & Profitability Analytics
--
-- The big picture: overall KPIs, the monthly trend, and how actual sales
-- compare with the monthly targets.
-- Built on: clean_sales_lines and clean_sales_target (see 02_cleaning.sql)
--
-- Definitions I use in every query in this project:
--   Revenue       = SUM(amount)
--   Profit        = SUM(profit)
--   Units         = SUM(quantity)
--   Orders        = COUNT(DISTINCT order_id)   (not COUNT(*), that counts lines)
--   AOV           = Revenue / Orders
--   Profit margin = Profit / Revenue
--
-- One assumption to be upfront about: the source doesn't say whether
-- Amount is before or after discounts, tax or returns. I call it
-- "revenue (Amount)" throughout and leave it at that.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1: KPI summary   (feeds the KPI cards in Tableau)
-- How big is the business, and how profitable is it?
-- SAFE_DIVIDE returns NULL instead of an error if the denominator is 0.
-- Expected: revenue 431502 | profit 23955 | profit_margin ~0.0555 |
--           orders 500 | units 5615 | avg_order_value 863.004 | customers 399
-- Note: customers uses the derived customer_key (name + state), so it's
-- an approximate count.
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
-- Q2: Monthly revenue and profit, with month-over-month growth
--     (feeds the monthly trend chart)
-- How do revenue and profit move from month to month?
-- I squash the data down to one row per month first (the CTE), then use
-- the window function LAG() to read the previous month's revenue. That
-- avoids a self-join. The first month has nothing before it, so its
-- growth is NULL.
-- Expected: 12 rows. First row Apr-18: revenue 32726, profit -3960,
--           orders 44, revenue_mom_growth NULL. Orders add up to 500.
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
--     (feeds the target attainment view)
-- Which categories actually hit their monthly sales targets?
--
-- Two rules I stuck to:
--   1) Aggregate BEFORE joining, so both sides are one row per
--      month x category and the join can't multiply rows.
--   2) LEFT JOIN from the target table, so a month with zero sales still
--      shows up (as 0) rather than disappearing.
-- Targets are compared against Amount (revenue).
--
-- Expected: 36 rows. SUM(target_amount) = 435900, SUM(actual_revenue) = 431502.
--           16 of the 36 category-months have hit_target = TRUE.
--           Quick check, Apr-18: Furniture 8121 vs 10400 (missed),
--                                Clothing 13478 vs 12000 (hit),
--                                Electronics 11127 vs 9000 (hit).
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
