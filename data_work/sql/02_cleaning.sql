-- =====================================================================
-- 02_cleaning.sql
-- Project : India E-Commerce Sales & Profitability Analytics
-- Purpose : Build the CLEAN layer as VIEWS on top of the raw tables.
--           Raw tables are never modified; cleaning logic stays visible
--           and re-runnable.
-- Layers  : raw_*  ->  clean_*  ->  clean_sales_lines (analysis base)
-- Run each CREATE statement separately, in this order.
-- =====================================================================


-- ---------------------------------------------------------------------
-- View 1: clean_orders   (grain: one row per order, 500 rows)
-- Fixes  : removes the 60 blank rows; TRIMs text; converts the date text
--          (DD-MM-YYYY) to a real DATE; corrects state to 'Delhi' where
--          city = 'Delhi'; adds an audit flag and a derived customer key.
-- Notes  : - state_was_corrected keeps a trail of the 3 Delhi fixes
--          - customer_key = name + state is a DERIVED PROXY. The dataset has
--            no customer ID, and some names appear in several states.
--          - Chandigarh appears under both Punjab and Haryana in the source.
--            It is retained as-is and flagged in the README.
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
-- View 2: clean_order_details   (grain: one row per order line, 1500 rows)
-- Fixes  : converts text to numbers with SAFE_CAST; TRIMs text.
-- Notes  : negative profits are RETAINED on purpose (business signal).
--          There is no line-item ID in the source, so lines cannot be
--          uniquely identified beyond order_id + values.
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
-- View 3: clean_sales_target   (grain: one row per month x category, 36 rows)
-- Fixes  : 'Apr-18' text -> DATE 2018-04-01 so it can join to order_month.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW `india-ecommerce-analytics.ecommerce.clean_sales_target` AS
SELECT
  PARSE_DATE('%b-%y', month_label) AS target_month,
  TRIM(category) AS category,
  SAFE_CAST(target AS FLOAT64) AS target_amount
FROM `india-ecommerce-analytics.ecommerce.raw_sales_target`;


-- ---------------------------------------------------------------------
-- View 4: clean_sales_lines   (ANALYSIS BASE; grain: one row per order line)
-- Why the join is safe: one order has many lines, but each line matches
--   exactly ONE order. Joining from the "many" side (details) to the "one"
--   side (orders) cannot multiply rows.
-- Counting rules for anything built on this view:
--   revenue = SUM(amount)              (never COUNT)
--   orders  = COUNT(DISTINCT order_id) (never COUNT(*) - that counts lines)
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
-- VALIDATION of the clean layer (run after creating all four views)
-- Expected:
--   orders = 500              states = 19            corrected_states = 3
--   customer_keys = 399       line_rows = 1500       distinct_orders = 500
--   total_amount = 431502     total_profit = 23955   total_qty = 5615
--   negative_profit_lines = 503   min_profit = -1981   max_profit = 1698
-- If total_amount matches the raw total, the join lost or duplicated nothing.
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
