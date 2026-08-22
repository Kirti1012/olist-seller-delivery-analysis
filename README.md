# olist-seller-delivery-analysis
Identifying sellers with systematic delivery delays after controlling for region and category
# Olist Seller Delivery Accountability Analysis

Analyzing 110K+ e-commerce orders from the Brazilian Olist marketplace to identify sellers whose delivery delays exceed what's expected for their region and product category — correcting for the common bias of blaming sellers in remote areas or slow-moving categories for delays that aren't actually their fault.

## Business Question

Which sellers are systematically causing delivery delays after controlling for region and product category, so that delays aren't wrongly blamed on sellers shipping to remote areas or selling inherently slow-moving product types?

## Data Source

Raw data: [Olist Brazilian E-Commerce Public Dataset (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — not included in this repo due to file size; download directly from Kaggle if reproducing this analysis.

## Pipeline

1. **SQL** (`/sql`) — Loaded and joined raw Olist tables; built seller-level aggregation with a minimum order-volume filter and region/category benchmark comparisons.
2. **Python** (`/python`) — Further analysis and validation of the SQL output, including revenue-at-risk modeling.
3. **Data** (`/data`) — Cleaned, merged, order-level dataset (`olist_seller_delay_analysis_final.csv`) combining orders, sellers, products, customers, and delay metrics.
4. **Power BI** (`/powerbi`) — Aggregated seller-level and state-level summary tables (`powerbi_ready_tables.xlsx`), including a true joint state × category benchmark, ready for dashboard import.

## Methodology Notes (read before drawing conclusions)

- **Late rate** is measured as delivered date vs. estimated delivery date (not total transit time), so this reflects lateness against the customer's promised delivery window.
- **Expected/benchmark late rate** is a joint state × category average — sellers are compared against others selling similar products into similar regions, not against a flat overall average.
- A **minimum of 20 orders** is required before a seller is included in the "systematic" ranking, to avoid flagging low-volume sellers on noise.
- **Revenue-at-risk** is a modeled proxy (excess bad-review rate on late orders × late-order revenue), not a confirmed financial loss or record of actual platform intervention — the dataset contains no field for actual seller suspensions or platform actions.
- This analysis does **not** separate seller handling time from carrier/courier transit time (the raw data lacks a clean seller-controlled milestone for this split), so "late" reflects total delay to the customer, not seller fault in isolation.

## Key Findings

- 881 sellers met the minimum order-volume threshold for inclusion.
- 371 of those sellers had late rates exceeding their region+category-adjusted expected rate.
- Estimated $403K in modeled revenue-at-risk across flagged sellers.

## Tools Used

SQL (MySQL) · Python (pandas) · Power BI · DAX · Power Query

## Author

Kirti Lulla — [LinkedIn](https://www.linkedin.com/in/kirti-lulla-405a60249/)

