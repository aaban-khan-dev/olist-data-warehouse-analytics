use OlistDW;
GO

-- customers: is customer_id unique? (note: customer_id vs customer_unique_id differ!)
SELECT COUNT(*) total, COUNT(DISTINCT customer_id) distinct_cust_id,
       COUNT(DISTINCT customer_unique_id) distinct_unique_id
FROM staging.customers;

-- orders: one row per order?
SELECT COUNT(*) total, COUNT(DISTINCT order_id) distinct_orders FROM staging.orders;

-- order_items: what's the grain? (hint: order_id alone is NOT unique)
SELECT COUNT(*) total,
       COUNT(DISTINCT order_id) distinct_orders,
       COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)) distinct_order_item
FROM staging.order_items;

-- products / sellers: unique on their id?
SELECT COUNT(*) total, COUNT(DISTINCT product_id) distinct_products FROM staging.products;
SELECT COUNT(*) total, COUNT(DISTINCT seller_id) distinct_sellers FROM staging.sellers;

-- order_reviews: unique on review_id? on order_id?
SELECT COUNT(*) total, COUNT(DISTINCT review_id) distinct_reviews,
       COUNT(DISTINCT order_id) distinct_orders FROM staging.order_reviews;

-- order_payments: grain?
SELECT COUNT(*) total,
       COUNT(DISTINCT CONCAT(order_id,'-',payment_sequential)) distinct_order_pay
FROM staging.order_payments;

-- geolocation: unique per zip?
SELECT COUNT(*) total, COUNT(DISTINCT geolocation_zip_code_prefix) distinct_zips
FROM staging.geolocation;



-- Every order_item references a real order?
SELECT COUNT(*) orphaned_items FROM staging.order_items oi
LEFT JOIN staging.orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Every order_item references a real product?
SELECT COUNT(*) items_missing_product FROM staging.order_items oi
LEFT JOIN staging.products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Every order references a real customer?
SELECT COUNT(*) orders_missing_customer FROM staging.orders o
LEFT JOIN staging.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Every product category has an English translation?
SELECT COUNT(DISTINCT p.product_category_name) categories_missing_translation
FROM staging.products p
LEFT JOIN staging.category_translation t
       ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL AND p.product_category_name IS NOT NULL;

-- Every order has a review? a payment? (these WON'T be 100% - that's a finding)
SELECT COUNT(*) orders_without_review FROM staging.orders o
LEFT JOIN staging.order_reviews r ON o.order_id = r.order_id
WHERE r.order_id IS NULL;

SELECT COUNT(*) orders_without_payment FROM staging.orders o
LEFT JOIN staging.order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;



-- Nulls in the delivery timestamps (central to delivery-vs-reviews analysis)
SELECT
  SUM(CASE WHEN order_delivered_customer_date IS NULL OR order_delivered_customer_date='' THEN 1 ELSE 0 END) AS null_delivered,
  SUM(CASE WHEN order_approved_at IS NULL OR order_approved_at='' THEN 1 ELSE 0 END) AS null_approved,
  COUNT(*) AS total
FROM staging.orders;

-- Order status distribution (why some deliveries are null - canceled/unavailable orders)
SELECT order_status, COUNT(*) cnt FROM staging.orders GROUP BY order_status ORDER BY cnt DESC;

-- Products with missing category (affects freight-by-category analysis)
SELECT COUNT(*) products_no_category FROM staging.products
WHERE product_category_name IS NULL OR product_category_name = '';

-- Price / freight sanity
SELECT MIN(price) min_price, MAX(price) max_price,
       MIN(freight_value) min_freight, MAX(freight_value) max_freight,
       SUM(CASE WHEN freight_value = 0 THEN 1 ELSE 0 END) zero_freight_rows
FROM staging.order_items;

-- Review scores range (should be 1-5)
SELECT review_score, COUNT(*) cnt FROM staging.order_reviews
GROUP BY review_score ORDER BY review_score;

--date range verification for dataset
SELECT MIN(TRY_CONVERT(datetime, order_purchase_timestamp)) earliest,
       MAX(TRY_CONVERT(datetime, order_purchase_timestamp)) latest,
       SUM(CASE WHEN TRY_CONVERT(datetime, order_purchase_timestamp) IS NULL THEN 1 ELSE 0 END) unparseable
FROM staging.orders;



-- A table to hold data quality check results as part of the pipeline
DROP TABLE IF EXISTS dq.staging_checks;
CREATE TABLE dq.staging_checks (
    check_name   VARCHAR(200),
    check_result VARCHAR(200),
    check_status VARCHAR(20),   -- PASS / WARN / FAIL
    checked_at   DATETIME DEFAULT GETDATE()
);
GO

-- Example: populate a couple of checks
INSERT INTO dq.staging_checks (check_name, check_result, check_status)
SELECT 'orders_row_count', CAST(COUNT(*) AS VARCHAR), 
       CASE WHEN COUNT(*) = 99441 THEN 'PASS' ELSE 'WARN' END
FROM staging.orders;

INSERT INTO dq.staging_checks (check_name, check_result, check_status)
SELECT 'orphaned_order_items', CAST(COUNT(*) AS VARCHAR),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END
FROM staging.order_items oi
LEFT JOIN staging.orders o ON oi.order_id = o.order_id WHERE o.order_id IS NULL;

SELECT * FROM dq.staging_checks;