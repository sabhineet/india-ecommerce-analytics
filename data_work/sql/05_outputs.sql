-- =====================================================================
-- 05_outputs.sql
-- India E-Commerce Sales & Profitability Analytics
--
-- Tableau Public can't connect to BigQuery directly, so I turn the final
-- results into small output tables and export each one as a CSV
-- (they live in data_work/tableau_exports/).
--
-- One rule: the tables hold additive numbers only (revenue, profit,
-- orders and so on). Margins are worked out in Tableau as
-- SUM(profit) / SUM(revenue). If a table stored a margin percentage,
-- Tableau would add or average it and get the wrong answer.
--
-- Run each statement separately and check the row count in the comment.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) out_kpi_summary   (expect 1 row: 431502 / 23955 / 5615 / 500)
-- Feeds the KPI cards.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `india-ecommerce-analytics.ecommerce.out_kpi_summary` AS
SELECT
  ROUND(SUM(amount), 0)     AS revenue,
  ROUND(SUM(profit), 0)     AS profit,
  SUM(quantity)             AS units,
  COUNT(DISTINCT order_id)  AS orders,
  COUNT(*)                  AS line_items,
  COUNTIF(profit < 0)       AS loss_lines
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`;


-- ---------------------------------------------------------------------
-- 2) out_monthly   (expect 12 rows)
-- Feeds the monthly trend chart.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `india-ecommerce-analytics.ecommerce.out_monthly` AS
WITH m AS (
  SELECT
    order_month,
    SUM(amount)              AS revenue,
    SUM(profit)              AS profit,
    SUM(quantity)            AS units,
    COUNT(DISTINCT order_id) AS orders
  FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
  GROUP BY order_month
)
SELECT
  order_month,
  ROUND(revenue, 0) AS revenue,
  ROUND(profit, 0)  AS profit,
  units,
  orders,
  ROUND(SAFE_DIVIDE(revenue - LAG(revenue) OVER (ORDER BY order_month),
                    LAG(revenue) OVER (ORDER BY order_month)) * 100, 1) AS revenue_mom_pct
FROM m
ORDER BY order_month;


-- ---------------------------------------------------------------------
-- 3) out_subcategory   (expect 17 rows)
-- Feeds the category and sub-category charts.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `india-ecommerce-analytics.ecommerce.out_subcategory` AS
SELECT
  category,
  sub_category,
  ROUND(SUM(amount), 0)  AS revenue,
  ROUND(SUM(profit), 0)  AS profit,
  SUM(quantity)          AS units,
  COUNT(*)               AS line_items,
  COUNTIF(profit < 0)    AS loss_lines
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
GROUP BY category, sub_category;


-- ---------------------------------------------------------------------
-- 4) out_state_city   (expect 25 rows)
-- Feeds the regional dashboard. The data_note column carries the
-- Chandigarh warning into Tableau's tooltips.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `india-ecommerce-analytics.ecommerce.out_state_city` AS
SELECT
  state,
  city,
  ROUND(SUM(amount), 0)     AS revenue,
  ROUND(SUM(profit), 0)     AS profit,
  SUM(quantity)             AS units,
  COUNT(DISTINCT order_id)  AS orders,
  IF(city = 'Chandigarh', 'Appears under both Punjab and Haryana in source data', NULL) AS data_note
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
GROUP BY state, city;


-- ---------------------------------------------------------------------
-- 5) out_customers   (expect 399 rows, 72 of them "Repeat (approx.)")
-- Customer = name + state, which is a proxy (see 02_cleaning.sql).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `india-ecommerce-analytics.ecommerce.out_customers` AS
SELECT
  customer_key,
  ANY_VALUE(customer_name)            AS customer_name,
  ANY_VALUE(state)                    AS state,
  ROUND(SUM(amount), 0)               AS revenue,
  ROUND(SUM(profit), 0)               AS profit,
  COUNT(DISTINCT order_id)            AS orders,
  IF(COUNT(DISTINCT order_id) > 1, 'Repeat (approx.)', 'One-time') AS segment
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
GROUP BY customer_key;


-- ---------------------------------------------------------------------
-- 6) out_target_vs_actual   (expect 36 rows)
-- Same logic as Q3 in 03_sales_kpis.sql, saved as a table. I rounded the
-- revenue and attainment, and dropped the ORDER BY because Tableau sorts
-- it anyway.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `india-ecommerce-analytics.ecommerce.out_target_vs_actual` AS
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
  ROUND(COALESCE(a.actual_revenue, 0), 0) AS actual_revenue,
  ROUND(SAFE_DIVIDE(COALESCE(a.actual_revenue, 0), t.target_amount), 4) AS attainment,
  COALESCE(a.actual_revenue, 0) >= t.target_amount AS hit_target
FROM `india-ecommerce-analytics.ecommerce.clean_sales_target` t
LEFT JOIN actual a
  ON a.target_month = t.target_month
 AND a.category = t.category;


-- ---------------------------------------------------------------------
-- Validation 1: do the five revenue tables still add up?
-- Every row should show revenue 431502 and profit 23955. A difference of
-- a rupee or two is fine, since each table rounds its own numbers.
-- Expected rows: kpi 1 | monthly 12 | subcategory 17 | state_city 25 | customers 399
-- ---------------------------------------------------------------------
SELECT 'kpi' AS tbl, COUNT(*) AS n, SUM(revenue) AS revenue, SUM(profit) AS profit FROM `india-ecommerce-analytics.ecommerce.out_kpi_summary`
UNION ALL SELECT 'monthly',     COUNT(*), SUM(revenue), SUM(profit) FROM `india-ecommerce-analytics.ecommerce.out_monthly`
UNION ALL SELECT 'subcategory', COUNT(*), SUM(revenue), SUM(profit) FROM `india-ecommerce-analytics.ecommerce.out_subcategory`
UNION ALL SELECT 'state_city',  COUNT(*), SUM(revenue), SUM(profit) FROM `india-ecommerce-analytics.ecommerce.out_state_city`
UNION ALL SELECT 'customers',   COUNT(*), SUM(revenue), SUM(profit) FROM `india-ecommerce-analytics.ecommerce.out_customers`;


-- ---------------------------------------------------------------------
-- Validation 2: the target table
-- Expected: n = 36 | total_target = 435900 | total_actual = 431502 |
--           months_hit = 16
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS n,
       SUM(target_amount) AS total_target,
       SUM(actual_revenue) AS total_actual,
       COUNTIF(hit_target) AS months_hit
FROM `india-ecommerce-analytics.ecommerce.out_target_vs_actual`;
