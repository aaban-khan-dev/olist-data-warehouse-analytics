-- 22_reconcile_postgres.sql
-- Parity check: the Postgres serving copy must agree with the SQL Server
-- warehouse before anything is built on top of it. Run the same checks on
-- both sides and compare.
--     psql -h localhost -U olist_app -d olist_dw -f 22_reconcile_postgres.sql

-- 1. Row counts
SELECT 'dim_order_status'      AS tbl, COUNT(*) AS n FROM mart.dim_order_status
UNION ALL SELECT 'dim_product',        COUNT(*) FROM mart.dim_product
UNION ALL SELECT 'dim_customer',       COUNT(*) FROM mart.dim_customer
UNION ALL SELECT 'dim_geography',      COUNT(*) FROM mart.dim_geography
UNION ALL SELECT 'dim_seller',         COUNT(*) FROM mart.dim_seller
UNION ALL SELECT 'dim_date',           COUNT(*) FROM mart.dim_date
UNION ALL SELECT 'fact_order_items',   COUNT(*) FROM mart.fact_order_items
UNION ALL SELECT 'fact_delivery_reviews', COUNT(*) FROM mart.fact_delivery_reviews
ORDER BY tbl;

-- 2. The headline financial total. Must be 13591643.70.
SELECT SUM(price)         AS total_revenue,
       SUM(freight_value) AS total_freight
FROM mart.fact_order_items;

-- 3. Unknown-member routing. Must match the orphan rates from the
--    SQL Server load; a changed number means rows were lost or remapped.
SELECT
    COUNT(*) FILTER (WHERE product_sk      = -1) AS unk_product,
    COUNT(*) FILTER (WHERE seller_sk       = -1) AS unk_seller,
    COUNT(*) FILTER (WHERE customer_sk     = -1) AS unk_customer,
    COUNT(*) FILTER (WHERE geography_sk    = -1) AS unk_geography,
    COUNT(*) FILTER (WHERE date_sk         = -1) AS unk_date,
    COUNT(*) FILTER (WHERE order_status_sk = -1) AS unk_status
FROM mart.fact_order_items;

-- 4. Boolean columns survived the BIT -> BOOLEAN conversion.
SELECT is_current, COUNT(*) FROM mart.dim_seller GROUP BY is_current;
SELECT is_weekend, COUNT(*) FROM mart.dim_date   GROUP BY is_weekend;

-- 5. Text columns are intact. The Olist geolocation feed ships city names
--    already unaccented, so this is a spot check for truncation or shifted
--    columns rather than an encoding check.
SELECT city, state, COUNT(*) AS zips
FROM mart.dim_geography
GROUP BY city, state
ORDER BY zips DESC
LIMIT 10;

-- 6. RFM segments carried over.
SELECT rfm_segment, COUNT(*) FROM mart.dim_customer
GROUP BY rfm_segment ORDER BY COUNT(*) DESC;

-- 7. The delivery/review headline relationship, as a behavioural check that
--    the fact table means the same thing it did in SQL Server.
SELECT is_late,
       COUNT(*)                        AS orders,
       ROUND(AVG(review_score), 2)     AS avg_review_score,
       ROUND(AVG(delivery_delay_days), 1) AS avg_delay_days
FROM mart.fact_delivery_reviews
WHERE is_delivered AND review_score IS NOT NULL
GROUP BY is_late;
