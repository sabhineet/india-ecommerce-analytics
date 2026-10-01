-- =====================================================================
-- 04_product_region_customer.sql
-- India E-Commerce Sales & Profitability Analytics
--
-- This is where the main question gets answered: which categories,
-- places and customers make profit, and not just revenue?
-- Built on: clean_sales_lines (see 02_cleaning.sql)
-- Numbering carries on from 03_sales_kpis.sql, so this file is Q4 to Q9.
--
-- Every query should add back to the same totals as before:
--   revenue 431502 | profit 23955 | units 5615 | orders 500
-- If one doesn't, something is wrong with the query, so I stop and check.
-- Under each query I've written what I noticed when I ran it.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q4: Revenue vs profit by category
-- Compare each category's share of revenue with its share of profit.
-- A big revenue share with a small profit share means sales are hiding a
-- low margin.
-- Note: the orders column won't add up to 500, because one order can
-- contain more than one category. That's normal.
--
-- What I noticed: Furniture is about 29% of revenue but only about 10% of
-- profit (1.8% margin). Clothing is the most profitable category even
-- though it ranks second on revenue.
-- ---------------------------------------------------------------------
SELECT
  category,
  ROUND(SUM(amount), 0)                                   AS revenue,
  ROUND(SUM(profit), 0)                                   AS profit,
  ROUND(SAFE_DIVIDE(SUM(profit), SUM(amount)) * 100, 1)   AS profit_margin_pct,
  SUM(quantity)                                           AS units,
  COUNT(DISTINCT order_id)                                AS orders,
  ROUND(SAFE_DIVIDE(SUM(amount), SUM(SUM(amount)) OVER ()) * 100, 1) AS revenue_share_pct,
  ROUND(SAFE_DIVIDE(SUM(profit), SUM(SUM(profit)) OVER ()) * 100, 1) AS profit_share_pct
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
GROUP BY category
ORDER BY revenue DESC;


-- ---------------------------------------------------------------------
-- Q5: Revenue vs profit by category and sub-category
-- Zooming in one level to see which products sit behind the category
-- numbers. loss_lines counts order lines with negative profit, and
-- loss_line_pct shows how common that is. A high percentage points at
-- something systematic (pricing, discounts) rather than a few unlucky
-- orders.
-- Checks: line_items should sum to 1500 and loss_lines to 503.
--
-- What I noticed:
--   - Tables lose 4,011 (-17.7% margin), which is more than the whole
--     Furniture category earns.
--   - Electronic Games is the only other loss-making sub-category.
--   - Saree brings in 53,511 in revenue but only 352 in profit (0.7%).
-- ---------------------------------------------------------------------
SELECT
  category,
  sub_category,
  ROUND(SUM(amount), 0)                                      AS revenue,
  ROUND(SUM(profit), 0)                                      AS profit,
  ROUND(SAFE_DIVIDE(SUM(profit), SUM(amount)) * 100, 1)      AS profit_margin_pct,
  SUM(quantity)                                              AS units,
  COUNT(*)                                                   AS line_items,
  COUNTIF(profit < 0)                                        AS loss_lines,
  ROUND(SAFE_DIVIDE(COUNTIF(profit < 0), COUNT(*)) * 100, 1) AS loss_line_pct
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
GROUP BY category, sub_category
ORDER BY category, profit ASC;


-- ---------------------------------------------------------------------
-- Q6: Performance by state
-- Revenue, profit, margin and average order value for each state, plus
-- each state's share of the company total.
-- Checks: orders should add up to 500 (each order belongs to one state)
-- and Delhi should show 25 orders (the 3 mislabelled ones are fixed).
--
-- What I noticed: Madhya Pradesh and Maharashtra together are about 46%
-- of revenue and 47% of profit. Tamil Nadu is the worst state (-2,216 on
-- only 8 orders), so I treat it as a flag, not a conclusion.
-- Be careful with Punjab and Haryana, see the Chandigarh note in Q7.
-- ---------------------------------------------------------------------
SELECT
  state,
  ROUND(SUM(amount), 0)                                                AS revenue,
  ROUND(SUM(profit), 0)                                                AS profit,
  ROUND(SAFE_DIVIDE(SUM(profit), SUM(amount)) * 100, 1)                AS profit_margin_pct,
  COUNT(DISTINCT order_id)                                             AS orders,
  ROUND(SAFE_DIVIDE(SUM(amount), COUNT(DISTINCT order_id)), 0)         AS avg_order_value,
  ROUND(SAFE_DIVIDE(SUM(amount), SUM(SUM(amount)) OVER ()) * 100, 1)   AS revenue_share_pct,
  ROUND(SAFE_DIVIDE(SUM(profit), SUM(SUM(profit)) OVER ()) * 100, 1)   AS profit_share_pct
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
GROUP BY state
ORDER BY revenue DESC;


-- ---------------------------------------------------------------------
-- Q7: Performance by city (state and city together)
-- Sorted by profit, lowest first, so the problem cities come up top.
-- Checks: orders should add up to 500 across 25 rows.
--
-- Chandigarh shows up twice, once under Punjab (16 orders) and once under
-- Haryana (14 orders). That comes from the source data, not from a bug
-- here. I left it alone because I can't tell which label is right.
-- Together it's 30 orders and roughly break-even, so Punjab's loss and
-- Haryana's profit both need to be read with that in mind.
--
-- What I noticed:
--   - Six city rows lose money, about 5,800 in total. Chennai is the
--     worst (-2,216 on 8 orders).
--   - Mumbai has the most orders (68) but a 2.6% margin, while Pune
--     earns 13.6%.
--   - The same state can hold winners and losers (Jaipur vs Udaipur,
--     Ahmedabad vs Surat), so state averages hide things.
-- ---------------------------------------------------------------------
SELECT
  state,
  city,
  ROUND(SUM(amount), 0)                                          AS revenue,
  ROUND(SUM(profit), 0)                                          AS profit,
  ROUND(SAFE_DIVIDE(SUM(profit), SUM(amount)) * 100, 1)          AS profit_margin_pct,
  COUNT(DISTINCT order_id)                                       AS orders,
  ROUND(SAFE_DIVIDE(SUM(amount), COUNT(DISTINCT order_id)), 0)   AS avg_order_value
FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
GROUP BY state, city
ORDER BY profit ASC;


-- ---------------------------------------------------------------------
-- Q8: Top 20 customers, with a running share of revenue
-- There's no customer ID in the data, so a customer here is name + state.
-- That's a proxy, so treat everything customer-related as approximate.
-- The running total (cumulative_revenue_pct) shows how concentrated
-- revenue is.
--
-- What I noticed: the top customer is only 2.1% of revenue and the top
-- 20 together are 23.8%, so there's no key-account risk. Four of the top
-- 20 actually lost money (Aarushi, Farah, Tulika, Shrichand). Aarushi
-- alone (-1,669) explains most of Tamil Nadu's loss.
-- ---------------------------------------------------------------------
WITH cust AS (
  SELECT
    CONCAT(customer_name, ' | ', state) AS customer_key,
    SUM(amount)                         AS revenue,
    SUM(profit)                         AS profit,
    COUNT(DISTINCT order_id)            AS orders
  FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
  GROUP BY customer_key
)
SELECT
  customer_key,
  ROUND(revenue, 0) AS revenue,
  ROUND(profit, 0)  AS profit,
  orders,
  ROUND(SAFE_DIVIDE(revenue, SUM(revenue) OVER ()) * 100, 1) AS revenue_share_pct,
  ROUND(SAFE_DIVIDE(
    SUM(revenue) OVER (ORDER BY revenue DESC),
    SUM(revenue) OVER ()) * 100, 1)                          AS cumulative_revenue_pct
FROM cust
ORDER BY revenue DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- Q9: Repeat vs one-time customers (approximate)
-- Anyone with more than one order counts as a repeat customer. Because
-- the customer is only name + state, two different people with the same
-- name in the same state would be merged, so I always label this
-- "approx."
-- Checks: customers should add up to 399 (72 repeat), revenue to 431502,
-- and profit to 23955.
--
-- What I noticed: repeat customers are about 18% of customers but 33% of
-- revenue, and spend roughly 2.3x as much each (2,002 vs 879). Their
-- margin is a little lower (5.1% vs 5.8%), so they add volume, not
-- better margins.
-- ---------------------------------------------------------------------
WITH cust AS (
  SELECT
    CONCAT(customer_name, ' | ', state) AS customer_key,
    COUNT(DISTINCT order_id)            AS orders,
    SUM(amount)                         AS revenue,
    SUM(profit)                         AS profit
  FROM `india-ecommerce-analytics.ecommerce.clean_sales_lines`
  GROUP BY customer_key
)
SELECT
  IF(orders > 1, 'Repeat (approx.)', 'One-time') AS segment,
  COUNT(*)                                       AS customers,
  ROUND(SUM(revenue), 0)                         AS revenue,
  ROUND(SUM(profit), 0)                          AS profit,
  ROUND(SAFE_DIVIDE(SUM(revenue), COUNT(*)), 0)  AS revenue_per_customer
FROM cust
GROUP BY segment;
