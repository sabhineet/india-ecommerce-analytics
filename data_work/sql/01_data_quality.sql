-- =====================================================================
-- 01_data_quality.sql
-- India E-Commerce Sales & Profitability Analytics
--
-- Before building anything, I wanted to know how messy the raw data was.
-- Everything in this file is read-only. It looks at the three raw tables
-- and changes nothing.
--
-- Tables : raw_orders, raw_order_details, raw_sales_target
--          I loaded every column as STRING on purpose, so BigQuery
--          couldn't guess types and quietly hide problems. The proper
--          typing happens later in 02_cleaning.sql.
-- Project: india-ecommerce-analytics   Dataset: ecommerce
--
-- How I used it: ran each query on its own and compared the result with
-- the "Expected" line above it.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1: How many real orders are there?
-- The orders file has blank rows at the bottom. NULLIF(TRIM(x), '')
-- turns both empty and whitespace-only values into NULL, so one test
-- catches both. COUNT(DISTINCT ...) skips NULLs, so blanks don't get
-- counted as an order.
-- Expected: total_rows = 560, blank_rows = 60, distinct_order_ids = 500
-- So: 500 real orders and no duplicate IDs, which means order_id can be
-- treated as the key.
-- ---------------------------------------------------------------------
SELECT
  COUNT(*) AS total_rows,
  COUNTIF(NULLIF(TRIM(order_id), '') IS NULL) AS blank_rows,
  COUNT(DISTINCT NULLIF(TRIM(order_id), '')) AS distinct_order_ids
FROM `india-ecommerce-analytics.ecommerce.raw_orders`;


-- ---------------------------------------------------------------------
-- Q2: Do the orders table and the order-details table line up?
-- If a detail row has no matching order (or the other way round), a join
-- would silently drop revenue. A LEFT JOIN with "right side IS NULL"
-- finds rows that have no match (an anti-join).
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
-- Q3: Hidden spaces in State
-- If LENGTH(state) is bigger than LENGTH(TRIM(state)), there's a stray
-- space at the start or end. These break joins and group-bys without
-- looking wrong on screen.
-- Expected: 19 rows. Kerala shows len = 7 vs trimmed_len = 6 (n = 16).
-- Fix: TRIM in 02_cleaning.sql
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
-- Q4: Orders where the city is Delhi but the state isn't
-- A city that contradicts its state is a labelling mistake in the source.
-- Expected: 3 rows -> B-25905 Bhargav, B-25909 Sujay, B-25913 Geetanjali,
-- all labelled "Madhya Pradesh".
-- Fix: set state to Delhi in the clean layer, and keep a flag so the
-- correction can be traced.
-- ---------------------------------------------------------------------
SELECT order_id, customer_name, state, city
FROM `india-ecommerce-analytics.ecommerce.raw_orders`
WHERE city = 'Delhi'
  AND TRIM(state) != 'Delhi';


-- ---------------------------------------------------------------------
-- Q5: Are the numbers sane?
-- SAFE_CAST gives NULL instead of an error when text can't be converted,
-- so the bad_* counts show any hidden bad values.
-- Expected: n = 1500; bad_amount / bad_profit / bad_qty = 0;
--           nonpositive_amount / nonpositive_qty = 0;
--           negative_profit_lines = 503; min_profit = -1981;
--           max_profit = 1698; max_amount = 5729
-- I'm keeping the 503 negative-profit lines. They aren't errors, they
-- are part of the business story.
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
-- order_date is text like DD-MM-YYYY, and the target month is text like
-- 'Apr-18'. SAFE.PARSE_DATE returns NULL when a value doesn't match the
-- format, so unparsed > 0 would mean bad dates.
-- Expected: orders.order_date  -> 500 non-blank, 0 unparsed,
--                                 2018-04-01 to 2019-03-31
--           target.month_label -> 36, 0 unparsed,
--                                 2018-04-01 to 2019-03-01
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
