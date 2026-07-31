Use OlistDW;
GO


-- Control table: one row per loadable table, storing its last-loaded watermark
DROP TABLE IF EXISTS dq.load_control;
GO

CREATE TABLE dq.load_control (
    table_name        VARCHAR(100) PRIMARY KEY,
    last_watermark    DATETIME NULL,      -- newest order_purchase_timestamp loaded so far
    last_load_time    DATETIME NULL,      -- when the load last ran
    rows_last_loaded  INT NULL
);
GO

-- Seed it. We set the watermark to the current max so a "normal" incremental
-- run finds nothing new (correct for a static source until we add a batch).
INSERT INTO dq.load_control (table_name, last_watermark, last_load_time, rows_last_loaded)
SELECT
    'fact_order_items',
    MAX(TRY_CONVERT(datetime, order_purchase_timestamp)),
    GETDATE(),
    0
FROM staging.orders;
GO

SELECT * FROM dq.load_control;



-- Incremental load procedure for fact_order_items.
-- Loads only order_items whose order was purchased AFTER the stored watermark,
-- then advances the watermark.
GO
CREATE OR ALTER PROCEDURE mart.load_fact_order_items_incremental
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @watermark DATETIME;
    SELECT @watermark = last_watermark
    FROM dq.load_control WHERE table_name = 'fact_order_items';

    -- Insert only NEW rows (order purchased after the watermark)
    INSERT INTO mart.fact_order_items (
        order_id, order_item_id, date_sk, product_sk, seller_sk,
        customer_sk, geography_sk, order_status_sk,
        price, freight_value, freight_pct, net_contribution
    )
    SELECT
        oi.order_id,
        oi.order_item_id,
        ISNULL(CONVERT(INT, FORMAT(TRY_CONVERT(datetime, o.order_purchase_timestamp), 'yyyyMMdd')), -1),
        ISNULL(dp.product_sk,  -1),
        ISNULL(ds.seller_sk,   -1),
        ISNULL(dc.customer_sk, -1),
        ISNULL(dg.geography_sk,-1),
        ISNULL(dos.order_status_sk, -1),
        oi.price,
        oi.freight_value,
        CASE WHEN oi.price > 0 THEN oi.freight_value / oi.price ELSE NULL END,
        oi.price - oi.freight_value
    FROM staging.order_items oi
    LEFT JOIN staging.orders o          ON oi.order_id = o.order_id
    LEFT JOIN mart.dim_product dp       ON oi.product_id = dp.product_id
    LEFT JOIN mart.dim_seller ds        ON oi.seller_id = ds.seller_id AND ds.is_current = 1
    LEFT JOIN staging.customers sc      ON o.customer_id = sc.customer_id
    LEFT JOIN mart.dim_customer dc      ON sc.customer_unique_id = dc.customer_unique_id
    LEFT JOIN mart.dim_geography dg     ON sc.customer_zip_code_prefix = dg.zip_code_prefix
    LEFT JOIN mart.dim_order_status dos ON o.order_status = dos.order_status
    -- THE INCREMENTAL FILTER: only orders newer than the watermark
    WHERE TRY_CONVERT(datetime, o.order_purchase_timestamp) > @watermark;

    DECLARE @rows INT = @@ROWCOUNT;

    -- Advance the watermark to the newest timestamp now present
    UPDATE dq.load_control
    SET last_watermark = (
            SELECT MAX(TRY_CONVERT(datetime, o.order_purchase_timestamp))
            FROM staging.orders o
        ),
        last_load_time   = GETDATE(),
        rows_last_loaded = @rows
    WHERE table_name = 'fact_order_items';

    PRINT CONCAT('Incremental load complete. Rows loaded: ', @rows);
END;
GO



EXEC mart.load_fact_order_items_incremental;
SELECT * FROM dq.load_control;



-- Roll watermark back 30 days to simulate a fresh batch arriving
UPDATE dq.load_control
SET last_watermark = DATEADD(DAY, -30, last_watermark)
WHERE table_name = 'fact_order_items';

-- Count how many rows SHOULD be picked up (orders in that 30-day window)
SELECT COUNT(*) AS expected_new_rows
FROM staging.order_items oi
JOIN staging.orders o ON oi.order_id = o.order_id
WHERE TRY_CONVERT(datetime, o.order_purchase_timestamp) >
      (SELECT last_watermark FROM dq.load_control WHERE table_name = 'fact_order_items');

-- Run the incremental load - should insert exactly that many
EXEC mart.load_fact_order_items_incremental;

-- Check the control table: rows_last_loaded should equal expected_new_rows
SELECT * FROM dq.load_control;


-- NOTE: The simulation above intentionally reloads a 30-day window to demonstrate
-- the incremental mechanism. 

