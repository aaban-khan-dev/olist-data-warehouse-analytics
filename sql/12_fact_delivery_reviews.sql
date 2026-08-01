-- 11_fact_delivery_reviews.sql — Phase 13: delivery + review fact for satisfaction analysis
USE OlistDW;
GO

DROP TABLE IF EXISTS mart.fact_delivery_reviews;
GO

CREATE TABLE mart.fact_delivery_reviews (
    delivery_review_sk   INT IDENTITY(1,1) PRIMARY KEY,
    order_id             VARCHAR(50) NOT NULL,
    customer_sk          INT NOT NULL,
    order_status_sk      INT NOT NULL,
    purchase_date_sk     INT NOT NULL,
    review_score         INT NULL,
    estimated_days       INT NULL,   -- purchase → estimated delivery
    actual_days          INT NULL,   -- purchase → actual delivery
    delivery_delay_days  INT NULL,   -- actual − estimated (positive = LATE)
    is_late              BIT NULL,   -- 1 if delivered after estimate
    is_delivered         BIT NULL
);
GO

INSERT INTO mart.fact_delivery_reviews (
    order_id, customer_sk, order_status_sk, purchase_date_sk,
    review_score, estimated_days, actual_days, delivery_delay_days, is_late, is_delivered
)
SELECT
    o.order_id,
    ISNULL(dc.customer_sk, -1),
    ISNULL(dos.order_status_sk, -1),
    ISNULL(CONVERT(INT, FORMAT(TRY_CONVERT(datetime, o.order_purchase_timestamp), 'yyyyMMdd')), -1),
    r.review_score,
    -- estimated delivery window in days
    DATEDIFF(DAY,
        TRY_CONVERT(datetime, o.order_purchase_timestamp),
        TRY_CONVERT(datetime, o.order_estimated_delivery_date)),
    -- actual delivery time in days
    DATEDIFF(DAY,
        TRY_CONVERT(datetime, o.order_purchase_timestamp),
        TRY_CONVERT(datetime, o.order_delivered_customer_date)),
    -- delay: actual − estimated (positive = delivered late)
    DATEDIFF(DAY,
        TRY_CONVERT(datetime, o.order_estimated_delivery_date),
        TRY_CONVERT(datetime, o.order_delivered_customer_date)),
    -- is_late flag
    CASE WHEN TRY_CONVERT(datetime, o.order_delivered_customer_date) >
              TRY_CONVERT(datetime, o.order_estimated_delivery_date)
         THEN 1 ELSE 0 END,
    -- is_delivered flag
    CASE WHEN o.order_status = 'delivered' THEN 1 ELSE 0 END
FROM staging.orders o
LEFT JOIN staging.customers sc     ON o.customer_id = sc.customer_id
LEFT JOIN mart.dim_customer dc     ON sc.customer_unique_id = dc.customer_unique_id
LEFT JOIN mart.dim_order_status dos ON o.order_status = dos.order_status
-- one review per order (take the latest if multiple)
LEFT JOIN (
    SELECT order_id, review_score,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_creation_date DESC) rn
    FROM staging.order_reviews
) r ON o.order_id = r.order_id AND r.rn = 1;
GO



-- Row count (should be ~99,441 - one per order)
SELECT COUNT(*) AS total FROM mart.fact_delivery_reviews;

-- The headline relationship: avg review score, on-time vs late (delivered orders only)
SELECT
    is_late,
    COUNT(*) AS orders,
    CAST(AVG(review_score * 1.0) AS DECIMAL(4,2)) AS avg_review_score,
    CAST(AVG(delivery_delay_days * 1.0) AS DECIMAL(6,1)) AS avg_delay_days
FROM mart.fact_delivery_reviews
WHERE is_delivered = 1 AND review_score IS NOT NULL
GROUP BY is_late;

-- Review score by delay buckets (does more delay = worse score?)
SELECT
    CASE
        WHEN delivery_delay_days <= -5 THEN '5+ days early'
        WHEN delivery_delay_days <  0  THEN 'Early'
        WHEN delivery_delay_days =  0  THEN 'On time'
        WHEN delivery_delay_days <= 5  THEN '1-5 days late'
        ELSE '5+ days late'
    END AS delivery_bucket,
    COUNT(*) AS orders,
    CAST(AVG(review_score*1.0) AS DECIMAL(4,2)) AS avg_score
FROM mart.fact_delivery_reviews
WHERE is_delivered = 1 AND review_score IS NOT NULL AND delivery_delay_days IS NOT NULL
GROUP BY CASE
        WHEN delivery_delay_days <= -5 THEN '5+ days early'
        WHEN delivery_delay_days <  0  THEN 'Early'
        WHEN delivery_delay_days =  0  THEN 'On time'
        WHEN delivery_delay_days <= 5  THEN '1-5 days late'
        ELSE '5+ days late'
    END
ORDER BY MIN(delivery_delay_days);