Use OlistDW;
GO



-- Build RFM base: one row per customer with raw recency/frequency/monetary
DROP TABLE IF EXISTS intermediate.rfm_base;
GO

-- Reference date = most recent purchase in the whole dataset
DECLARE @max_date DATE;
SELECT @max_date = MAX(TRY_CONVERT(date, order_purchase_timestamp)) FROM staging.orders;

SELECT
    dc.customer_sk,
    dc.customer_unique_id,
    -- Recency: days from customer's last order to the reference date
    DATEDIFF(DAY, MAX(TRY_CONVERT(date, o.order_purchase_timestamp)), @max_date) AS recency_days,
    -- Frequency: number of distinct orders
    COUNT(DISTINCT o.order_id) AS frequency,
    -- Monetary: total spend (item price + freight)
    SUM(oi.price + oi.freight_value) AS monetary
INTO intermediate.rfm_base
FROM mart.dim_customer dc
JOIN staging.customers sc ON dc.customer_unique_id = sc.customer_unique_id
JOIN staging.orders o     ON sc.customer_id = o.customer_id
JOIN staging.order_items oi ON o.order_id = oi.order_id
WHERE dc.customer_sk > 0   -- exclude the unknown member
GROUP BY dc.customer_sk, dc.customer_unique_id;
GO

-- Sanity check
SELECT COUNT(*) AS customers,
       AVG(recency_days) AS avg_recency,
       AVG(frequency*1.0) AS avg_frequency,
       AVG(monetary) AS avg_monetary
FROM intermediate.rfm_base;



DROP TABLE IF EXISTS intermediate.rfm_scores;
GO

SELECT
    customer_sk,
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    -- Recency: fewer days = better, so reverse the ntile (6 - ntile)
    6 - NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
    -- Frequency: more orders = better
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
    -- Monetary: more spend = better
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
INTO intermediate.rfm_scores
FROM intermediate.rfm_base;
GO

SELECT TOP 10 * FROM intermediate.rfm_scores ORDER BY monetary DESC;



DROP TABLE IF EXISTS intermediate.rfm_scores;
GO

SELECT
    customer_sk,
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    -- Recency: fewer days = better, so reverse the ntile (6 - ntile)
    6 - NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
    -- Frequency: more orders = better
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
    -- Monetary: more spend = better
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
INTO intermediate.rfm_scores
FROM intermediate.rfm_base;
GO

SELECT TOP 10 * FROM intermediate.rfm_scores ORDER BY monetary DESC;




DROP TABLE IF EXISTS intermediate.rfm_segments;
GO

SELECT
    customer_sk,
    customer_unique_id,
    r_score, f_score, m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_cell,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
        WHEN r_score >= 3 AND m_score >= 4                  THEN 'Big Spenders'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
        WHEN r_score <= 2 AND m_score >= 4                  THEN 'Can''t Lose Them'
        WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost'
        ELSE 'Needs Attention'
    END AS rfm_segment
INTO intermediate.rfm_segments
FROM intermediate.rfm_scores;
GO

-- See the segment distribution
SELECT rfm_segment, COUNT(*) AS customers,
       CAST(AVG(monetary) AS DECIMAL(10,2)) AS avg_spend
FROM intermediate.rfm_segments s
JOIN intermediate.rfm_base b ON s.customer_sk = b.customer_sk
GROUP BY rfm_segment
ORDER BY customers DESC;



UPDATE dc
SET dc.rfm_segment = s.rfm_segment
FROM mart.dim_customer dc
JOIN intermediate.rfm_segments s ON dc.customer_sk = s.customer_sk;
GO

-- Unknown member and any unscored customers → 'Unknown'
UPDATE mart.dim_customer
SET rfm_segment = 'Unknown'
WHERE rfm_segment IS NULL;
GO

-- Verify the dimension now carries segments
SELECT rfm_segment, COUNT(*) AS customers
FROM mart.dim_customer
GROUP BY rfm_segment
ORDER BY customers DESC;