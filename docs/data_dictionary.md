# Data dictionary

This explains every table in the project, what each column means, and how it was made. Everything lives in the BigQuery project `india-ecommerce-analytics`, dataset `ecommerce`.

The tables come in three layers:

```
raw_*   ->   clean_*   ->   out_*
(as loaded)  (typed, fixed)  (small tables exported to Tableau)
```

---

## 1. Raw tables (as loaded from the CSVs)

Every column is stored as text (STRING) on purpose. I wanted to see the problems in the data before any type conversion could hide them.

### raw_orders (560 rows, 500 of them real)

| Column | Meaning |
|---|---|
| order_id | Order number, like `B-25601`. Blank on 60 rows |
| order_date | Date as text, `DD-MM-YYYY` |
| customer_name | First name of the customer |
| state | State, in some cases with a trailing space (`Kerala `) |
| city | City |

### raw_order_details (1,500 rows)

One row per product line inside an order.

| Column | Meaning |
|---|---|
| order_id | Links to `raw_orders` |
| amount | Line amount in rupees (called "revenue" in this project) |
| profit | Line profit in rupees. Can be negative |
| quantity | Units on the line |
| category | Clothing, Electronics or Furniture |
| sub_category | 17 sub-categories, such as Saree, Tables, Phones |

### raw_sales_target (36 rows)

| Column | Meaning |
|---|---|
| month_label | Month as text, like `Apr-18` |
| category | Clothing, Electronics or Furniture |
| target | Monthly sales target in rupees |

---

## 2. Clean views (made in `02_cleaning.sql`)

| View | One row per | Rows | What changed |
|---|---|---|---|
| clean_orders | order | 500 | Blank rows dropped, text trimmed, date converted, Delhi fixed, `customer_key` added |
| clean_order_details | order line | 1,500 | Text converted to numbers, text trimmed |
| clean_sales_target | month x category | 36 | `Apr-18` converted to a real date |
| clean_sales_lines | order line | 1,500 | Orders and details joined. **Base for all analysis** |

### Columns added or changed in the clean layer

| Column | Where | Meaning |
|---|---|---|
| order_date | clean_orders | Real DATE |
| order_month | clean_orders | First day of the order's month (`2018-04-01`), used for monthly grouping |
| state | clean_orders | Cleaned. Set to `Delhi` whenever city is Delhi |
| state_was_corrected | clean_orders | TRUE for the 3 Delhi orders that were fixed |
| customer_key | clean_orders | `customer_name \| state`. **A proxy, not a real customer ID** |
| target_month | clean_sales_target | Real DATE, matches `order_month` |
| target_amount | clean_sales_target | Target as a number |

---

## 3. Output tables (made in `05_outputs.sql`, exported to `tableau_exports/`)

These hold additive numbers only. Margins are calculated in Tableau as `SUM(profit) / SUM(revenue)`.

### out_kpi_summary (1 row)

| Column | Meaning |
|---|---|
| revenue | Total revenue (431,502) |
| profit | Total profit (23,955) |
| units | Units sold (5,615) |
| orders | Distinct orders (500) |
| line_items | Order lines (1,500) |
| loss_lines | Lines with negative profit (503) |

### out_monthly (12 rows)

| Column | Meaning |
|---|---|
| order_month | First day of the month |
| revenue, profit, units, orders | Monthly totals |
| revenue_mom_pct | Revenue growth against the previous month, in %. Empty for April 2018 |

### out_subcategory (17 rows)

| Column | Meaning |
|---|---|
| category, sub_category | Product group |
| revenue, profit, units | Totals |
| line_items | Order lines |
| loss_lines | Lines with negative profit |

### out_state_city (25 rows)

| Column | Meaning |
|---|---|
| state, city | Location |
| revenue, profit, units, orders | Totals |
| data_note | Warning text for Chandigarh (it appears under two states in the source). Empty for the others |

### out_customers (399 rows)

| Column | Meaning |
|---|---|
| customer_key | Name + state, the customer proxy |
| customer_name, state | Parts of the key |
| revenue, profit, orders | Totals per customer |
| segment | `Repeat (approx.)` if more than one order, otherwise `One-time` |

### out_target_vs_actual (36 rows)

| Column | Meaning |
|---|---|
| target_month | First day of the month |
| category | Product category |
| target_amount | Sales target |
| actual_revenue | Actual revenue for that month and category |
| attainment | Actual divided by target (1.0 = 100%) |
| hit_target | TRUE if actual met or beat the target |

---

## Definitions used everywhere

| Measure | Formula |
|---|---|
| Revenue | `SUM(amount)` |
| Profit | `SUM(profit)` |
| Units | `SUM(quantity)` |
| Orders | `COUNT(DISTINCT order_id)` (not `COUNT(*)`, which counts lines) |
| Average order value | Revenue / Orders |
| Profit margin | Profit / Revenue |

## Known quirks

- **Chandigarh** appears under both Punjab and Haryana in the source data. I kept it as is.
- **Revenue** is the `amount` column. The source doesn't say whether it is before or after discounts or tax.
- **Customer** is a proxy built from name + state. Two different people with the same name in the same state would be counted as one.
- **Negative profit lines** (503) are kept on purpose.
