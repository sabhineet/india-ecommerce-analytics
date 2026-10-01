-- =====================================================================
-- 02_cleaning.sql
-- India E-Commerce Sales & Profitability Analytics
--
-- This builds the clean layer. I used views instead of rewriting the
-- raw tables, so the originals are never touched and every cleaning
-- step stays visible and easy to re-run.
--
-- Layers: raw_*  ->  clean_*  ->  clean_sales_lines (the base for all analysis)
-- Run each CREATE statement on its own, in the order below.
-- =====================================================================


-- ---------------------------------------------------------------------
-- View 1: clean_orders   (one row per order, 500 rows)
--
-- What it fixes:
--   - drops the 60 blank rows
--   - trims stray spaces (the "Kerala " problem)
--   - turns the DD-MM-YYYY text into a real DATE
--   - sets state to Delhi when the city is Delhi (3 orders were labelled
--     Madhya Pradesh)
--
-- Two things worth knowing:
--   - state_was_corrected keeps a trail of those 3 Delhi fixes.
--   - There is no customer ID in this dataset, so customer_key is
--     name + state. It's a proxy, not a real ID, and some names show up
--     in more than one state. Anything built on it is approximate.
--   - Chandigarh appears under both Punjab and Haryana in the source.
--     I left it as it is and noted it in the README.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW `india-ecommerce-analytics.ecommerce.clean_orders` AS
WITH base AS (
  SELECT
    TRIM(order_id) AS order_id,
    PARSE_DATE('%d-%m-%Y', order_date) AS order_date,
    TRIM(customer_name) AS customer_name,
    TRIM(state) AS state_raw,
    TRIM(city) AS city
  FROM `india-ecommerce-analytics.ecommerce.raw_orders`
  WHERE NULLIF(TRIM(order_id), '') IS NOT NULL      -- drop the 60 blank rows
),
fixed AS (
  SELECT
    *,
    CASE WHEN city = 'Delhi' THEN 'Delhi' ELSE state_raw END AS state
  FROM base
)
SELECT
  order_id,
  order_date,
  DATE_TRUNC(order_date, MONTH) AS order_month,
  customer_name,
  state,
  city,
  state != state_raw AS state_was_corrected,
  CONCAT(customer_name, ' | ', state) AS customer_key
FROM fixed;


-- ---------------------------------------------------------------------
-- View 2: clean_order_details   (one row per order line, 1500 rows)
--
-- Text becomes numbers using SAFE_CAST, and text columns get trimmed.
-- Negative profits stay in on purpose, since losing money on a line is
-- exactly what I'm trying to find.
-- The source has no line-item ID, so a line can't be uniquely identified
-- beyond order_id plus its values.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW `india-ecommerce-analytics.ecommerce.clean_order_details` AS
SELECT
  TRIM(order_id) AS order_id,
  SAFE_CAST(amount AS FLOAT64) AS amount,
  SAFE_CAST(profit AS FLOAT64) AS profit,
  SAFE_CAST(quantity AS INT64) AS quantity,
  TRIM(category) AS category,
  TRIM(sub_category) AS sub_category
FROM `india-ecommerce-analytics.ecommerce.raw_order_details`;


-- ---------------------------------------------------------------------
-- View 3: clean_sales_target   (one row per month x category, 36 rows)
--
-- 'Apr-18' is text. I convert it to a DATE (2018-04-01) so it can be
-- joined to order_month later.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW `india-ecommerce-analytics.ecommerce.clean_sales_target` AS
SELECT
  PARSE_DATE('%b-%y', month_label) AS target_month,
  TRIM(category) AS category,
  SAFE_CAST(target AS FLOAT64) AS target_amount
FROM `india-ecommerce-analytics.ecommerce.raw_sales_target`;


-- ---------------------------------------------------------------------
-- View 4: clean_sales_lines   (the analysis base, one row per order line)
--
-- Why this join is safe: one order has many lines, but each line belongs
-- to exactly one order. Joining from the "many" side (details) to the
-- "one" side (orders) can't multiply rows.
--
-- Two counting rules I follow in everything built on this view:
--   revenue = SUM(amount)              (never COUNT)
--   orders  = COUNT(DISTINCT order_id) (never COUNT(*), that counts lines)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW `india-ecommerce-analytics.ecommerce.clean_sales_lines` AS
SELECT
  o.order_id,
  o.order_date,
  o.order_month,
  o.customer_name,
  o.customer_key,
  o.state,
  o.city,
  d.category,
  d.sub_category,
  d.amount,
  d.profit,
  d.quantity
FROM `india-ecommerce-analytics.ecommerce.clean_order_details` d
JOIN `india-ecommerce-analytics.ecommerce.clean_orders` o
  ON d.order_id = o.order_id;


-- ---------------------------------------------------------------------
-- Validation of the clean layer (run after creating all four views)
--
-- If total_amount matches the raw total, the join lost nothing and
-- duplicated nothing.
-- Expected:
--   orders = 500              states = 19            corrected_states = 3
--   customer_keys = 399       line_rows = 1500       distinct_orders = 500
--   total_amount = 431502     total_profit = 23955   total_qty = 5615
--   negative_profit_lines = 503   min_profit = -1981   max_profit = 1698
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM `india-ecommerce-analytics.ecommerce.clean_orders`) AS orders,
  (SELECT COUNT(DISTINCT state) FROM `india-ecommerce-analytics.ecommerce.clean_orders`) AS states,
  (SELECT COUNTIF(state_was_corrected) FROM `india-ecommerce-analytics.ecommerce.clean_orders`) AS corrected_states,
  (SELECT COUNT(DISTINCT customer_key) FROM `india-ecommerce-analytics.ecommerce.clean_orders`) AS customer_keys,
  COUNT(*) AS line_rows,
  COUNT(DISTINCT order_id) AS distinct_orders,
  SUM(amount) AS total_amount,
  SUM(profit) AS total_profit,
  SUM(quantity) AS total_qty,
  COUNTIF(profit < 0) AS negative_profit_lines,
  MIN(profit) AS min_profit,
  MAX(profit) AS max_profit
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`;
