Use OlistDW;
GO

DROP TABLE IF EXISTS mart.fact_order_items;
GO

CREATE TABLE mart.fact_order_items (
    order_item_sk    INT IDENTITY(1,1) PRIMARY KEY,
    order_id         VARCHAR(50) NOT NULL,     -- degenerate dimension (kept for traceability)
    order_item_id    INT NOT NULL,
    date_sk          INT NOT NULL,
    product_sk       INT NOT NULL,
    seller_sk        INT NOT NULL,
    customer_sk      INT NOT NULL,
    geography_sk     INT NOT NULL,
    order_status_sk  INT NOT NULL,
    price            DECIMAL(18,2) NULL,
    freight_value    DECIMAL(18,2) NULL,
    freight_pct      DECIMAL(9,4) NULL,        -- freight / price
    net_contribution DECIMAL(18,2) NULL        -- price - freight (margin proxy)
);
GO



INSERT INTO mart.fact_order_items (
    order_id, order_item_id, date_sk, product_sk, seller_sk,
    customer_sk, geography_sk, order_status_sk,
    price, freight_value, freight_pct, net_contribution
)
SELECT
    oi.order_id,
    oi.order_item_id,
    -- date_sk from the order's purchase timestamp (YYYYMMDD int)
    ISNULL(CONVERT(INT, FORMAT(TRY_CONVERT(datetime, o.order_purchase_timestamp), 'yyyyMMdd')), -1) AS date_sk,
    ISNULL(dp.product_sk,  -1) AS product_sk,
    ISNULL(ds.seller_sk,   -1) AS seller_sk,
    ISNULL(dc.customer_sk, -1) AS customer_sk,
    ISNULL(dg.geography_sk,-1) AS geography_sk,
    ISNULL(dos.order_status_sk, -1) AS order_status_sk,
    oi.price,
    oi.freight_value,
    -- derived measures
    CASE WHEN oi.price > 0 THEN oi.freight_value / oi.price ELSE NULL END AS freight_pct,
    oi.price - oi.freight_value AS net_contribution
FROM staging.order_items oi
-- link item to its order (for date, customer, status)
LEFT JOIN staging.orders o        ON oi.order_id = o.order_id
-- product lookup
LEFT JOIN mart.dim_product dp     ON oi.product_id = dp.product_id
-- seller lookup (only current SCD-2 version)
LEFT JOIN mart.dim_seller ds      ON oi.seller_id = ds.seller_id AND ds.is_current = 1
-- customer: order → staging.customers (customer_id) → dim_customer (customer_unique_id)
LEFT JOIN staging.customers sc    ON o.customer_id = sc.customer_id
LEFT JOIN mart.dim_customer dc    ON sc.customer_unique_id = dc.customer_unique_id
-- geography: customer's zip → dim_geography
LEFT JOIN mart.dim_geography dg   ON sc.customer_zip_code_prefix = dg.zip_code_prefix
-- order status lookup
LEFT JOIN mart.dim_order_status dos ON o.order_status = dos.order_status;
GO

-- Should be 112,650 (every order_item row lands; none dropped)
SELECT COUNT(*) AS total_facts FROM mart.fact_order_items;

-- How many routed to Unknown members? (tells you the orphan rate)
SELECT
    SUM(CASE WHEN product_sk      = -1 THEN 1 ELSE 0 END) AS unk_product,
    SUM(CASE WHEN seller_sk       = -1 THEN 1 ELSE 0 END) AS unk_seller,
    SUM(CASE WHEN customer_sk     = -1 THEN 1 ELSE 0 END) AS unk_customer,
    SUM(CASE WHEN geography_sk    = -1 THEN 1 ELSE 0 END) AS unk_geography,
    SUM(CASE WHEN date_sk         = -1 THEN 1 ELSE 0 END) AS unk_date,
    SUM(CASE WHEN order_status_sk = -1 THEN 1 ELSE 0 END) AS unk_status
FROM mart.fact_order_items;

-- Sanity: total revenue should match your profiling (~13,591,643.70)
SELECT SUM(price) AS total_revenue, SUM(freight_value) AS total_freight
FROM mart.fact_order_items;




-- fact payment
DROP TABLE IF EXISTS mart.fact_payments;
GO

CREATE TABLE mart.fact_payments (
    payment_sk          INT IDENTITY(1,1) PRIMARY KEY,
    order_id            VARCHAR(50) NOT NULL,
    payment_sequential  INT NOT NULL,
    date_sk             INT NOT NULL,
    customer_sk         INT NOT NULL,
    order_status_sk     INT NOT NULL,
    payment_type        VARCHAR(30) NULL,
    payment_installments INT NULL,
    payment_value       DECIMAL(18,2) NULL
);
GO

INSERT INTO mart.fact_payments (
    order_id, payment_sequential, date_sk, customer_sk, order_status_sk,
    payment_type, payment_installments, payment_value
)
SELECT
    op.order_id,
    op.payment_sequential,
    ISNULL(CONVERT(INT, FORMAT(TRY_CONVERT(datetime, o.order_purchase_timestamp), 'yyyyMMdd')), -1),
    ISNULL(dc.customer_sk, -1),
    ISNULL(dos.order_status_sk, -1),
    op.payment_type,
    op.payment_installments,
    op.payment_value
FROM staging.order_payments op
LEFT JOIN staging.orders o          ON op.order_id = o.order_id
LEFT JOIN staging.customers sc      ON o.customer_id = sc.customer_id
LEFT JOIN mart.dim_customer dc      ON sc.customer_unique_id = dc.customer_unique_id
LEFT JOIN mart.dim_order_status dos ON o.order_status = dos.order_status;
GO

-- Verify: should be 103,886
SELECT COUNT(*) AS total_payments FROM mart.fact_payments;
-- Payment total sanity
SELECT SUM(payment_value) AS total_payments_value FROM mart.fact_payments;