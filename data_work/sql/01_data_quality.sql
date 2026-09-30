-- =====================================================================
-- 01_data_quality.sql
-- Project : India E-Commerce Sales & Profitability Analytics
-- Purpose : Read-only checks on the RAW tables. Nothing is changed.
-- Tables  : raw_orders, raw_order_details, raw_sales_target
--           (all columns loaded as STRING on purpose; typed later in 02_cleaning.sql)
-- Project ID used below: india-ecommerce-analytics  (dataset: ecommerce)
-- Run each query separately and compare with the "Expected" line.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1: How many real orders do we have?
-- Why: the orders file has blank rows. NULLIF(TRIM(x), '') turns empty AND
--      whitespace-only values into NULL, so one test catches both.
--      COUNT(DISTINCT ...) ignores NULLs, so blanks are not counted as an order.
-- Expected: total_rows = 560, blank_rows = 60, distinct_order_ids = 500
-- Meaning : 500 real orders, no duplicate order IDs -> order_id can be the key.
-- ---------------------------------------------------------------------
SELECT
  COUNT(*) AS total_rows,
  COUNTIF(NULLIF(TRIM(order_id), '') IS NULL) AS blank_rows,
  COUNT(DISTINCT NULLIF(TRIM(order_id), '')) AS distinct_order_ids
FROM `india-ecommerce-analytics.ecommerce.raw_orders`;


-- ---------------------------------------------------------------------
-- Q2: Do the orders table and the order-details table match up?
-- Why: a LEFT JOIN ... WHERE right_side IS NULL finds rows with NO match
--      (an "anti-join"). Orphan rows would silently drop revenue in joins.
-- Expected: details_without_order = 0, orders_without_details = 0
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(*)
   FROM `india-ecommerce-analytics.ecommerce.raw_order_details` d
   LEFT JOIN `india-ecommerce-analytics.ecommerce.raw_orders` o
     ON d.order_id = o.order_id
   WHERE o.order_id IS NULL) AS details_without_order,
  (SELECT COUNT(*)
   FROM `india-ecommerce-analytics.ecommerce.raw_orders` o
   LEFT JOIN (SELECT DISTINCT order_id
              FROM `india-ecommerce-analytics.ecommerce.raw_order_details`) d
     ON o.order_id = d.order_id
   WHERE NULLIF(TRIM(o.order_id), '') IS NOT NULL
     AND d.order_id IS NULL) AS orders_without_details;


-- ---------------------------------------------------------------------
-- Q3: Hidden whitespace in State
-- Why: compare LENGTH(state) with LENGTH(TRIM(state)); a difference means
--      leading/trailing spaces. Such values break joins and lookups.
-- Expected: 19 rows. Kerala shows len = 7 vs trimmed_len = 6 (n = 16).
-- Action  : correct with TRIM in 02_cleaning.sql
-- ---------------------------------------------------------------------
SELECT
  state,
  LENGTH(state) AS len,
  LENGTH(TRIM(state)) AS trimmed_len,
  COUNT(*) AS n
FROM `india-ecommerce-analytics.ecommerce.raw_orders`
WHERE state IS NOT NULL
GROUP BY state
ORDER BY state;


-- ---------------------------------------------------------------------
-- Q4: Orders whose city is Delhi but whose state is not Delhi
-- Why: a city/state contradiction means a labelling error in the source.
-- Expected: 3 rows -> B-25905 Bhargav, B-25909 Sujay, B-25913 Geetanjali
--           (all with state "Madhya Pradesh")
-- Action  : correct state to Delhi in the clean layer and keep an audit flag
-- ---------------------------------------------------------------------
SELECT order_id, customer_name, state, city
FROM `india-ecommerce-analytics.ecommerce.raw_orders`
WHERE city = 'Delhi'
  AND TRIM(state) != 'Delhi';


-- ---------------------------------------------------------------------
-- Q5: Are the numeric fields sane?
-- Why: SAFE_CAST returns NULL instead of an error when text cannot be
--      converted, so the bad_* counts reveal hidden bad values.
-- Expected: n = 1500; bad_amount / bad_profit / bad_qty = 0;
--           nonpositive_amount / nonpositive_qty = 0;
--           negative_profit_lines = 503; min_profit = -1981;
--           max_profit = 1698; max_amount = 5729
-- Note    : negative profit lines are RETAINED - they are a business signal,
--           not a data error.
-- ---------------------------------------------------------------------
SELECT
  COUNT(*) AS n,
  COUNTIF(SAFE_CAST(amount AS FLOAT64) IS NULL) AS bad_amount,
  COUNTIF(SAFE_CAST(profit AS FLOAT64) IS NULL) AS bad_profit,
  COUNTIF(SAFE_CAST(quantity AS INT64) IS NULL) AS bad_qty,
  COUNTIF(SAFE_CAST(amount AS FLOAT64) <= 0) AS nonpositive_amount,
  COUNTIF(SAFE_CAST(quantity AS INT64) <= 0) AS nonpositive_qty,
  COUNTIF(SAFE_CAST(profit AS FLOAT64) < 0) AS negative_profit_lines,
  MIN(SAFE_CAST(profit AS FLOAT64)) AS min_profit,
  MAX(SAFE_CAST(profit AS FLOAT64)) AS max_profit,
  MAX(SAFE_CAST(amount AS FLOAT64)) AS max_amount
FROM `india-ecommerce-analytics.ecommerce.raw_order_details`;


-- ---------------------------------------------------------------------
-- Q6: Do the dates parse?
-- Why: order_date is text in DD-MM-YYYY and the target month is text like
--      'Apr-18'. SAFE.PARSE_DATE returns NULL if a value does not match the
--      format, so unparsed > 0 would mean bad dates.
-- Expected: orders.order_date      -> 500 non-blank, 0 unparsed, 2018-04-01 to 2019-03-31
--           target.month_label     -> 36, 0 unparsed, 2018-04-01 to 2019-03-01
-- ---------------------------------------------------------------------
SELECT
  'orders.order_date' AS field,
  COUNT(*) AS non_blank,
  COUNTIF(SAFE.PARSE_DATE('%d-%m-%Y', order_date) IS NULL) AS unparsed,
  MIN(SAFE.PARSE_DATE('%d-%m-%Y', order_date)) AS first_date,
  MAX(SAFE.PARSE_DATE('%d-%m-%Y', order_date)) AS last_date
FROM `india-ecommerce-analytics.ecommerce.raw_orders`
WHERE NULLIF(TRIM(order_id), '') IS NOT NULL
UNION ALL
SELECT
  'target.month_label',
  COUNT(*),
  COUNTIF(SAFE.PARSE_DATE('%b-%y', month_label) IS NULL),
  MIN(SAFE.PARSE_DATE('%b-%y', month_label)),
  MAX(SAFE.PARSE_DATE('%b-%y', month_label))
FROM `india-ecommerce-analytics.ecommerce.raw_sales_target`;
