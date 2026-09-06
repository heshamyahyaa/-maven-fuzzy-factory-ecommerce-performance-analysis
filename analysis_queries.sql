/* =====================================================================
   MAVEN FUZZY FACTORY — BUSINESS ANALYTICS HACKATHON
   Analysis & Insights Queries
   =====================================================================

   These queries run on the CLEANED tables produced after the data
   quality phase (suffix "_clean" for orders, order_items,
   website_sessions, website_pageviews, order_item_refunds).
   The `products` table required no cleaning and is used as-is.

   All results here feed the Power BI dashboard — this file documents
   the SQL logic behind each business question; visualisation and
   further slicing happens in Power BI.

   Table of Contents
   -------------------------------------------------------------------
   0. Headline KPIs
   1. Best Performing Traffic Channel
   2. Best Performing Device Type
   3. Product Profitability
   4. Cross-Sell / Products Bought Together
   5. Cross-Sell Feature: Before vs After Impact
   6. Repeat vs New Customer Value
   7. Supporting Lookups (A/B test date windows)
   ===================================================================== */


/* ---------------------------------------------------------------------
   0. HEADLINE KPIs
   ---------------------------------------------------------------------
   Business question: What are the overall business numbers investors
   will see first — total revenue, total profit, average order value,
   and order count?
   Logic: Straight aggregation over the cleaned orders table.
--------------------------------------------------------------------- */
SELECT 
    ROUND(SUM(price_usd), 0) AS total_revenue,
    ROUND(SUM(price_usd - cogs_usd), 0) AS total_profit,
    ROUND(AVG(price_usd), 2) AS avg_order_value,
    COUNT(*) AS total_orders
FROM orders_clean;


/* ---------------------------------------------------------------------
   1. BEST PERFORMING TRAFFIC CHANNEL
   ---------------------------------------------------------------------
   Business question: Which acquisition channel (utm_source) brings in
   the most orders and profit, and at what average order value?
   Logic: Join orders to their originating session to recover the
   utm_source, then aggregate order count, AOV, and total profit per
   channel, ranked by profit.
--------------------------------------------------------------------- */
SELECT 
    ws.utm_source,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(AVG(o.price_usd), 2) AS avg_order_value,
    ROUND(SUM(o.price_usd - o.cogs_usd), 0) AS total_profit
FROM orders_clean o
JOIN website_sessions_clean ws ON o.website_session_id = ws.website_session_id
GROUP BY ws.utm_source
ORDER BY total_profit DESC;


/* ---------------------------------------------------------------------
   2. BEST PERFORMING DEVICE TYPE
   ---------------------------------------------------------------------
   Business question: Do desktop or mobile visitors generate more
   orders, and is there a difference in order value or profit?
   Logic: Same pattern as above, grouped by device_type instead of
   channel.
--------------------------------------------------------------------- */
SELECT 
    ws.device_type,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(AVG(o.price_usd), 2) AS avg_order_value,
    ROUND(SUM(o.price_usd - o.cogs_usd), 0) AS total_profit
FROM orders_clean o
JOIN website_sessions_clean ws ON o.website_session_id = ws.website_session_id
GROUP BY ws.device_type;


/* ---------------------------------------------------------------------
   3. PRODUCT PROFITABILITY
   ---------------------------------------------------------------------
   Business question: Which product generates the most total profit,
   and which has the healthiest margin?
   Logic: Aggregate at the order_items level (not orders) since this
   table holds price/cost per individual line item, joined to products
   for readable names. Margin % = (price - cost) / price.
--------------------------------------------------------------------- */
SELECT 
    p.product_name,
    ROUND(SUM(oi.price_usd - oi.cogs_usd), 0) AS total_profit,
    ROUND((SUM(oi.price_usd - oi.cogs_usd) / SUM(oi.price_usd)) * 100, 2) AS margin_percent,
    ROUND(SUM(oi.price_usd - oi.cogs_usd) / COUNT(DISTINCT oi.order_id), 2) AS profit_per_order
FROM order_items_clean oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_profit DESC;


/* ---------------------------------------------------------------------
   4. CROSS-SELL / PRODUCTS BOUGHT TOGETHER
   ---------------------------------------------------------------------
   Business question: When a customer buys Product A as their primary
   item, which product is most often added alongside it, and how much
   extra profit does that pairing generate?
   Logic: Self-join order_items_clean on order_id — oi1 is the primary
   item (is_primary_item = 1), oi2 is a non-primary item added to the
   same order (is_primary_item = 0). The "total" subquery counts how
   many times each product was ever bought as a primary item, used as
   the denominator for the attachment rate.

   NOTE: this query runs across the full dataset. The hackathon brief
   asks the cross-sell matrix to be restricted to orders placed after
   December 5, 2014 (when the Mini Bear became a standalone product,
   enabling the richer cross-sell dynamic). Add:
       WHERE oi1.order_id IN (SELECT order_id FROM orders_clean 
                               WHERE created_at >= '2014-12-05')
   if you want the matrix scoped exactly to the brief's window.
--------------------------------------------------------------------- */
SELECT 
    p1.product_name AS primary_product,
    p2.product_name AS cross_sell_product,
    COUNT(*) AS times_sold_together,
    ROUND(COUNT(*) * 100.0 / total.primary_count, 2) AS attachment_rate,
    ROUND(AVG(oi2.price_usd - oi2.cogs_usd), 2) AS avg_extra_profit,
    ROUND(COUNT(*) * AVG(oi2.price_usd - oi2.cogs_usd), 0) AS total_extra_profit
FROM order_items_clean oi1
JOIN order_items_clean oi2 ON oi1.order_id = oi2.order_id
JOIN products p1 ON oi1.product_id = p1.product_id
JOIN products p2 ON oi2.product_id = p2.product_id
JOIN (
    SELECT product_id, COUNT(*) AS primary_count
    FROM order_items_clean
    WHERE is_primary_item = 1
    GROUP BY product_id
) total ON oi1.product_id = total.product_id
WHERE oi1.is_primary_item = 1 
  AND oi2.is_primary_item = 0
GROUP BY p1.product_name, p2.product_name, total.primary_count
ORDER BY times_sold_together DESC;


/* ---------------------------------------------------------------------
   5. CROSS-SELL FEATURE: BEFORE VS AFTER IMPACT
   ---------------------------------------------------------------------
   Business question: Did adding the cross-sell option at checkout
   (launched September 25, 2013) actually increase order value and
   revenue?
   Logic: A simple before/after split on order date.

   NOTE: this compares ALL orders before Sept 25 2013 vs ALL orders
   after it. The brief's suggested methodology is a tighter one-month
   window on each side (Aug 25 – Sep 24, 2013 vs Sep 25 – Oct 24,
   2013) to isolate the feature's effect from other changes over time.
   Worth deciding — and stating in the deck — which comparison you're
   presenting, since the two can tell different stories.
--------------------------------------------------------------------- */
SELECT 
    CASE WHEN o.created_at < '2013-09-25' THEN 'Before Cross-sell' ELSE 'After Cross-sell' END AS period,
    ROUND(AVG(o.price_usd), 2) AS avg_order_value,
    ROUND(SUM(o.price_usd), 0) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS orders
FROM orders_clean o
GROUP BY period;


/* ---------------------------------------------------------------------
   6. REPEAT VS NEW CUSTOMER VALUE
   ---------------------------------------------------------------------
   Business question: Are returning customers more valuable than
   first-time visitors — more orders, higher AOV, more revenue?
   Logic: Group by the is_repeat_session flag on the session table,
   joined to orders.

   NOTE: the brief scopes this analysis to 2014 year-to-date data
   specifically. This query runs over the full dataset instead. Add
   `WHERE ws.created_at >= '2014-01-01'` if you want it to match the
   brief's exact scope.
--------------------------------------------------------------------- */
SELECT 
    ws.is_repeat_session,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT ws.user_id) AS unique_customers,
    ROUND(AVG(o.price_usd), 2) AS avg_order_value,
    ROUND(SUM(o.price_usd), 0) AS total_revenue
FROM website_sessions_clean ws
JOIN orders_clean o ON ws.website_session_id = o.website_session_id
GROUP BY ws.is_repeat_session;


/* ---------------------------------------------------------------------
   7. SUPPORTING LOOKUPS — A/B TEST DATE WINDOWS
   ---------------------------------------------------------------------
   Business question: What are the exact first/last-seen dates for the
   landing page and billing page A/B test variants? These lookups were
   used to confirm the correct comparison windows before running the
   test analysis (see Challenge 06 in the hackathon brief).
--------------------------------------------------------------------- */

-- First and last time /lander-1 appears in the data
SELECT MIN(created_at), MAX(created_at)
FROM website_pageviews_clean
WHERE pageview_url = '/lander-1';

-- First and last time /billing-2 appears in the data
SELECT MIN(created_at), MAX(created_at)
FROM website_pageviews_clean
WHERE pageview_url = '/billing-2';

-- First appearance of /billing-2 (marks the start of the billing test)
SELECT MIN(created_at) FROM website_pageviews_clean WHERE pageview_url = '/billing-2';

-- Last time the old /billing page was shown before /billing-2 took over
SELECT MAX(created_at) FROM website_pageviews_clean 
WHERE pageview_url = '/billing' 
  AND created_at < (SELECT MAX(created_at) FROM website_pageviews_clean WHERE pageview_url = '/billing-2');

-- Landing page A/B test: conversion rate for /home vs /lander-1,
-- restricted to the official test window (June 19 – July 28, 2012)
SELECT 
    wp.pageview_url,
    COUNT(DISTINCT wp.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT wp.website_session_id), 2) AS cvr
FROM website_pageviews_clean wp
LEFT JOIN orders_clean o ON wp.website_session_id = o.website_session_id
WHERE wp.pageview_url IN ('/home', '/lander-1')
  AND wp.created_at BETWEEN '2012-06-19' AND '2012-07-28'
GROUP BY wp.pageview_url;
