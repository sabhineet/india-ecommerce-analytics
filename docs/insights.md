# Insights and recommendations

Each finding follows the same four steps: what I **observed**, the **evidence** behind it, what I think it **means**, and what I'd **do** about it.

One thing to keep in mind throughout: the dataset has no cost, discount or campaign fields. I can show *where* profit is low, but not *why*. So the "what it means" and "what to do" parts are hypotheses to test, not conclusions.

All figures are in rupees and come from the validated queries in `data_work/sql/`.

---

## 1. Furniture sells a lot and keeps little

**Observation.** Furniture brings in nearly a third of revenue but very little of the profit.

**Evidence.**
- Revenue ₹127,181 (about 29% of the total) but profit only ₹2,298 (about 10%). Margin: 1.8%.
- **Tables** lose ₹4,011 (a -17.7% margin), and about 65% of Table order lines lose money.
- Bookcases, the profitable Furniture line, earn 8.6%.
- Without Tables, Furniture would have made roughly ₹6,300.

**What it likely means.** The weak margin is mostly a Tables problem, not a whole-category problem. The data can't say why. Heavy discounting or high costs would both fit.

**What I'd do.** Look at Table pricing and discount rules first, then supplier costs. Use Bookcases as the benchmark for what a healthy Furniture line looks like.

*Query: Q4 and Q5 in `04_product_region_customer.sql`.*

---

## 2. Saree: lots of revenue, almost no profit

**Observation.** The third-largest sub-category by revenue earns close to nothing.

**Evidence.**
- ₹53,511 in revenue (about 12% of the total) for ₹352 in profit. Margin: 0.7%.
- About 47% of Saree order lines lose money.
- Electronic Games is the only other loss-making sub-category (-₹1,236).

**What it likely means.** Selling more Sarees on current terms adds volume, not profit.

**What I'd do.** Test slightly higher prices or smaller discounts on Saree, and watch whether volume holds up.

*Query: Q5.*

---

## 3. Six months of losses, then a turnaround

**Observation.** The business lost money every month from April to September 2018, and was profitable every month from October.

**Evidence.**
- April to September lost about ₹21,800 in total (each month between about -₹2,100 and -₹5,000).
- October to March made about ₹45,750.
- November was the most profitable month (₹11,619).
- July revenue fell 45% against June, to ₹12,966.

**What it likely means.** Something changed around October. It could be product mix, pricing or seasonality, and with only 12 months of data I can't tell a seasonal pattern from a one-off change.

**What I'd do.** Find out what changed in October (prices, promotions, product mix) and whether it can be repeated. Ask for more history to test for seasonality.

*Query: Q2 in `03_sales_kpis.sql`.*

---

## 4. A few places carry the business, and a few lose money

**Observation.** Two states dominate, and a handful of cities lose money.

**Evidence.**
- Madhya Pradesh and Maharashtra together: about 46% of revenue and 47% of profit.
- Six city rows lose money, about ₹5,800 in total. Without them, profit would be about ₹29,800 instead of ₹23,955.
- Mumbai has the most orders (68) but a 2.6% margin. Pune earns 13.6%.
- Chennai lost ₹2,216 on only 8 orders, and most of that is one customer.
- The same state can hold winners and losers: Jaipur (-7.5%) vs Udaipur (+18.2%), Ahmedabad (-6.2%) vs Surat (+19.7%).

**What it likely means.** State averages hide the real picture. Some losses are about what happens inside a city (pricing or product mix), not about the state. Chennai is a flag to look into, not a conclusion, because 8 orders is a small sample.

**What I'd do.** Compare Mumbai's pricing and mix with Pune's. Review the orders behind the loss-making cities before drawing conclusions about any of them.

*Note on Chandigarh: it appears under both Punjab and Haryana in the source (30 orders, roughly break-even). That makes Punjab look worse and Haryana look better than they probably are.*

*Query: Q6 and Q7.*

---

## 5. Targets were missed more often than met

**Observation.** Only 16 of 36 category-month targets were reached.

**Evidence.**
- Electronics hit its target in 9 of 12 months, Furniture in 4, Clothing in 3.
- Total revenue was ₹431,502 against ₹435,900 in targets, which is 99%.
- Clothing in July reached only 21% of target. Electronics in December reached 206%.

**What it likely means.** The overall target looks reasonable, but the monthly targets don't follow how sales really move. Strong months make up for weak ones.

**What I'd do.** Set targets per category and shape them around the seasonal pattern, instead of using a flat step up month to month.

*Query: Q3.*

---

## 6. Repeat customers matter, but no single customer does

**Observation.** A small group of customers spends more, but revenue isn't concentrated in a few accounts.

**Evidence.**
- Repeat customers (approximate) are 18% of customers (72 of 399) but 33% of revenue. They spend about 2.3x as much each (₹2,002 vs ₹879).
- Their margin is 5.1%, slightly below one-time customers at 5.8%.
- The top customer is only 2.1% of revenue. The top 20 are 23.8%.
- Four of the top 20 customers lost money (about -₹2,900 combined).

**What it likely means.** Repeat customers bring volume, not better margins. There's little risk from losing any one account, but being a big spender doesn't mean being a profitable one.

**What I'd do.** Encourage repeat purchases, but check the margin on large orders before offering big customers special terms.

*Caveat: "customer" here is name + state, so these numbers are approximate.*

*Query: Q8 and Q9.*

---

## What I can't conclude

- **Why** margins are low. There is no cost, discount or campaign data.
- Whether the October turnaround is **seasonal**, with only 12 months of data.
- Anything exact about **customers**, because there is no customer ID.
- Anything about **Punjab vs Haryana**, because of how Chandigarh appears in the data.
- Whether `amount` is **before or after discounts and tax**. The source doesn't say.
- This is a **public dataset with an unknown author**, so none of it should be described as real company data.
