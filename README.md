# Maven Fuzzy Factory — Business Analytics Hackathon

**Team:** Avenger Team
**Tools:** MySQL · Excel · Power BI
**Deliverable:** End-to-end e-commerce growth analysis for a US direct-to-consumer toy retailer, from raw database to investor-ready recommendations.

MavenFuzzyFactory is a US-based e-commerce company selling stuffed animal toys online since March 2012. This project cleans and analyzes the company's full customer journey data — sessions, pageviews, and orders — to answer eight core business questions about growth, efficiency, funnel performance, product mix, and customer retention, and to deliver strategic recommendations backed by evidence.

---

## Repository Structure

```
├── data/
│   ├── raw/                        Raw database dump, exactly as received (schema + data)
│   └── processed/                  Cleaned tables, exported after data-quality fixes
├── sql/
│   └── analysis_queries.sql        Commented SQL used for the business analysis
├── dashboard/
│   └── maven_fuzzy_factory.pbix    Power BI dashboard (3 pages)
├── docs/
│   └── insights_and_recommendations.md   Key findings and the strategic action plan
└── presentation/
    ├── maven_fuzzy_factory_deck.pptx     Final investor deck
    └── maven_fuzzy_factory_deck.pdf      Same deck, viewable directly on GitHub
```

---

## Data Workflow

1. **Raw extraction** — the original six-table MySQL dump (`website_sessions`, `website_pageviews`, `products`, `orders`, `order_items`, `order_item_refunds`) is kept in `data/raw/` exactly as received, compressed with gzip for size. To restore it locally, unzip the file and follow the standard MySQL Workbench import steps (Server → Data Import, or run the script directly).
2. **Data quality audit** — before any analysis, the raw data was audited and cleaned. Issues found and corrected included:
   - Case and whitespace inconsistency in `utm_source` / `utm_campaign` fields (e.g. `'Gsearch'`, `'GSEARCH'`, `'gsearch'` all referring to the same channel)
   - Order line items referencing a `product_id` that doesn't exist in the products table
   - Orders with zero, negative, or cost-exceeds-price values
   - Duplicate session records sharing the same `user_id` and timestamp
3. **Cleaning** — most cleaning was done in SQL directly against the MySQL database; some additional transformation was done in Power Query within Power BI. The cleaned tables (suffixed `_clean`) were exported to `data/processed/` as CSVs.
4. **Analysis** — business questions were answered with the SQL in `sql/analysis_queries.sql`, further sliced and visualized in Power BI.

---

## Dashboard Overview

The Power BI dashboard has three pages:

- **Overview** — headline KPIs (sessions, orders, AOV, conversion rate, revenue, profit), channel and device performance, product profitability
- **Traffic & Funnel Analysis** — visitor behavior, weekly traffic patterns, the purchase funnel, and refund rates by product
- **A/B Tests & Cross-sell** — landing page and billing page experiment results, seasonality, and the cross-sell attachment matrix

---

## Key Findings

Full detail in [`docs/insights_and_recommendations.md`](docs/insights_and_recommendations.md). Highlights:

- **Channel paradox:** Google Paid drives the most volume and revenue, but SocialBook — despite minimal traffic — converts the highest-value customers by Average Order Value.
- **Biggest funnel leak:** the largest drop-off in the entire purchase funnel happens between the product detail page and the cart step, not at checkout.
- **A/B test win:** the redesigned billing page delivered a 37.3% conversion lift and is a strong candidate for full rollout.
- **Margin vs. quality trade-off:** the highest-margin product also carries the highest refund rate, worth a quality audit.

---

## Team

Avenger Team — MavenFuzzyFactory Business Analytics Hackathon submission.

**Prepared by:** Hesham Yahya — Data Analyst, Avenger Team
