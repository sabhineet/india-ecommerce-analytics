# India E-Commerce: Sales & Profitability Analytics

A small end-to-end analytics project: raw CSVs into BigQuery, cleaned with SQL, explored for sales and profit, and shown in three Tableau dashboards.

I wanted to practise the whole job, not just one piece of it. So I loaded messy data, cleaned it, checked every number against the source, and then wrote up what I found and what I'd suggest doing about it.

**The short version:** the business sold ₹431,502 but made only ₹23,955 in profit (a 5.6% margin). Sales volume is not the problem. Where the sales come from is.

---

## The question

I framed this as a junior analyst at an Indian online retailer. Leadership wants to know:

- Which categories and states drive **profit**, not just revenue?
- Where do high sales hide low margins?
- How does performance compare with the monthly targets?
- Which customers matter most?

## How it works

```
Kaggle CSVs -> BigQuery raw tables -> clean views -> analysis queries
            -> output tables -> CSV exports -> Tableau dashboards -> insights
```

1. **Load:** the three source files go into BigQuery as raw tables, with every column as text so nothing gets silently reinterpreted.
2. **Check:** six data-quality queries look for blanks, mismatches, hidden spaces and bad numbers (`01_data_quality.sql`).
3. **Clean:** four views fix what I found, without touching the raw tables (`02_cleaning.sql`).
4. **Analyse:** queries for KPIs, the monthly trend, targets, products, regions and customers (`03` and `04`).
5. **Export:** six small output tables, saved as CSVs for Tableau (`05_outputs.sql`).
6. **Visualise:** three dashboards in Tableau, checked against BigQuery.

## Dashboards

**Executive Overview**

![Executive Overview](data_work/tableau_exports/dashboard/Executive%20Overview.png)

**Regional Performance**

![Regional Performance](data_work/tableau_exports/dashboard/Regional%20Performance.png)

**Product & Customer**

![Product and Customer](data_work/tableau_exports/dashboard/Product%20%26%20Customer.png)

The Tableau workbook is in `data_work/tableau_exports/` (`Book1.twb`). It needs Tableau to open, and it points at the CSVs by their location on my computer, so the screenshots above are the easiest way to see the result. I haven't published it to Tableau Public.

## What I found

The full write-up, with the evidence for each point, is in [`docs/insights.md`](docs/insights.md). Here are the main points.

1. **Furniture sells a lot and keeps little.** It is about 29% of revenue but only about 10% of profit (1.8% margin). Most of that comes from **Tables**, which lose ₹4,011 on their own.
2. **Saree is the "busy but not profitable" product.** ₹53.5k in revenue (12% of the total) for ₹352 profit, a 0.7% margin.
3. **The business lost money for six months, then turned around.** Every month from April to September 2018 was a loss. Every month from October onwards made money.
4. **Two states carry the business.** Madhya Pradesh and Maharashtra are about 46% of revenue and 47% of profit. Six city rows lose money, led by Chennai. Mumbai has the most orders but earns a 2.6% margin, while Pune earns 13.6%.
5. **Targets were missed more often than hit.** Only 16 of 36 category-months reached target, even though total revenue came to 99% of the total target.
6. **Repeat customers are worth more, but not more profitable per rupee.** They are about 18% of customers and 33% of revenue. No single customer is more than 2.1% of revenue.

## Numbers I checked along the way

I kept a short list of totals and made sure every table and every dashboard matched them. If a number drifted, I stopped and found out why.

| Check | Value |
|---|---|
| Rows in raw tables (orders / details / targets) | 560 / 1,500 / 36 |
| Real orders after removing blank rows | 500 |
| Revenue | ₹431,502 |
| Profit | ₹23,955 |
| Units | 5,615 |
| Loss-making order lines | 503 |
| Customers (name + state proxy) | 399 (72 repeat) |
| Target total vs actual | ₹435,900 vs ₹431,502 |

## Data problems I found and what I did

| Problem | What I did |
|---|---|
| 60 blank rows in the orders file | Removed in the clean view |
| Trailing space in "Kerala " | Trimmed |
| 3 Delhi orders labelled Madhya Pradesh | Set state to Delhi, kept a flag column |
| Chandigarh listed under both Punjab and Haryana | Left as is, noted on the dashboard |
| 503 order lines with negative profit | Kept. They are part of the story, not errors |
| Dates stored as text | Converted to real dates |

## Repository structure

```
india_ecommerce_analytics/
├── README.md
├── docs/
│   ├── data_dictionary.md        <- every table and column explained
│   └── insights.md               <- six findings with evidence and suggested actions
├── raw_data/                     <- the three original CSVs, untouched
└── data_work/
    ├── sql/
    │   ├── 01_data_quality.sql
    │   ├── 02_cleaning.sql
    │   ├── 03_sales_kpis.sql
    │   ├── 04_product_region_customer.sql
    │   └── 05_outputs.sql
    └── tableau_exports/
        ├── dashboard/            <- dashboard screenshots
        ├── out_*.csv             <- the six files Tableau reads
        └── Book1.twb             <- Tableau workbook
```

## How to reproduce it

1. Create a BigQuery project and a dataset called `ecommerce`.
2. Load the three CSVs from `raw_data/` as `raw_orders`, `raw_order_details` and `raw_sales_target`. Use the column names that appear in `01_data_quality.sql` (for example `order_id`, `order_date`, `sub_category`, `month_label`) and set every column to STRING.
3. Replace `india-ecommerce-analytics` in the SQL files with your own project ID.
4. Run the SQL files in order, one statement at a time. Each query has an "Expected" line so you can see whether you got the same result.
5. Export the `out_*` tables as CSV and connect them in Tableau as separate data sources. I didn't join them, because they have different levels of detail and joining would inflate the totals.

## Tools

BigQuery (SQL), Tableau, Git and GitHub.

## Limitations

I'd rather say these upfront than have someone find them later.

- **No cost, discount or campaign data.** I can show where profit is low, but not why. Anything about causes in my write-up is a hypothesis to test.
- **No customer ID.** I used name + state as a stand-in, so customer and "repeat" figures are approximate.
- **Only 12 months** (April 2018 to March 2019), so I can't separate seasonality from one-off events.
- **Small samples in places.** Some cities have fewer than 15 orders, so their margins can swing a lot. Chennai's loss, for example, is mostly one customer.
- **Chandigarh is in the data twice** (under Punjab and Haryana), so state comparisons for those two need care.
- **"Revenue" is the Amount column.** The source doesn't say whether it's before or after discounts or tax.
- **This is a public dataset with an unknown original author.** It is not real company data, and I've framed the business scenario myself.

## Data source

Indian E-Commerce dataset on Kaggle ([benroshan/ecommerce-data](https://www.kaggle.com/datasets/benroshan/ecommerce-data)), CC0 licence. It has three files: List of Orders, Order Details and Sales Target. It was uploaded to Kaggle by benroshan, and the original author isn't stated.

## About

Built by Abhineet Srivastava as a portfolio project.

- LinkedIn: [abhineet-srivastava-](https://www.linkedin.com/in/abhineet-srivastava-/)
- Kaggle: [abhineetsrivastavaa](https://www.kaggle.com/abhineetsrivastavaa)
