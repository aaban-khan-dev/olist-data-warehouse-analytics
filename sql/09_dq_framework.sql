Use OlistDW;
GO


-- to hold every check's outcome
DROP TABLE IF EXISTS dq.check_results;
GO

CREATE TABLE dq.check_results (
    check_id      INT IDENTITY(1,1) PRIMARY KEY,
    check_category VARCHAR(50),    -- reconciliation / completeness / integrity / validity / uniqueness
    check_name    VARCHAR(200),
    expected      VARCHAR(100),
    actual        VARCHAR(100),
    status        VARCHAR(10),     -- PASS / FAIL / WARN
    checked_at    DATETIME DEFAULT GETDATE()
);
GO



CREATE OR ALTER PROCEDURE dq.run_quality_checks
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dq.check_results;   -- fresh run each time

    ---------------------------------------------------------------
    -- 1. RECONCILIATION: warehouse totals match source
    ---------------------------------------------------------------
    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'reconciliation', 'fact_order_items row count',
           '112650', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 112650 THEN 'PASS' ELSE 'FAIL' END
    FROM mart.fact_order_items;

    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'reconciliation', 'fact revenue matches staging',
           CAST(CAST((SELECT SUM(price) FROM staging.order_items) AS DECIMAL(18,2)) AS VARCHAR),
           CAST(CAST(SUM(price) AS DECIMAL(18,2)) AS VARCHAR),
           CASE WHEN CAST(SUM(price) AS DECIMAL(18,2)) =
                     CAST((SELECT SUM(price) FROM staging.order_items) AS DECIMAL(18,2))
                THEN 'PASS' ELSE 'FAIL' END
    FROM mart.fact_order_items;

    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'reconciliation', 'fact_payments row count',
           '103886', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 103886 THEN 'PASS' ELSE 'FAIL' END
    FROM mart.fact_payments;

    ---------------------------------------------------------------
    -- 2. INTEGRITY: every fact FK resolves to a real dimension row
    --    (no fact should point to a non-existent surrogate key)
    ---------------------------------------------------------------
    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'integrity', 'fact_order_items product_sk valid',
           '0', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM mart.fact_order_items f
    LEFT JOIN mart.dim_product d ON f.product_sk = d.product_sk
    WHERE d.product_sk IS NULL;

    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'integrity', 'fact_order_items customer_sk valid',
           '0', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM mart.fact_order_items f
    LEFT JOIN mart.dim_customer d ON f.customer_sk = d.customer_sk
    WHERE d.customer_sk IS NULL;

    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'integrity', 'fact_order_items date_sk valid',
           '0', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM mart.fact_order_items f
    LEFT JOIN mart.dim_date d ON f.date_sk = d.date_sk
    WHERE d.date_sk IS NULL;

    ---------------------------------------------------------------
    -- 3. UNIQUENESS: dimension business keys are unique among current rows
    ---------------------------------------------------------------
    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'uniqueness', 'dim_customer unique_id no dupes',
           '0', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM (SELECT customer_unique_id FROM mart.dim_customer
          GROUP BY customer_unique_id HAVING COUNT(*) > 1) x;

    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'uniqueness', 'dim_seller one current per seller_id',
           '0', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM (SELECT seller_id FROM mart.dim_seller WHERE is_current = 1
          GROUP BY seller_id HAVING COUNT(*) > 1) x;

    ---------------------------------------------------------------
    -- 4. VALIDITY: values fall in acceptable ranges
    ---------------------------------------------------------------
    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'validity', 'no negative prices',
           '0', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM mart.fact_order_items WHERE price < 0;

    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'validity', 'review scores in 1-5 (staging)',
           '0', CAST(COUNT(*) AS VARCHAR),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM staging.order_reviews
    WHERE review_score IS NOT NULL AND (review_score < 1 OR review_score > 5);

    ---------------------------------------------------------------
    -- 5. COMPLETENESS: unknown-member routing rate (WARN, not FAIL)
    ---------------------------------------------------------------
    INSERT INTO dq.check_results (check_category, check_name, expected, actual, status)
    SELECT 'completeness', 'geography unknown rate',
           '<5%',
           CAST(CAST(SUM(CASE WHEN geography_sk = -1 THEN 1 ELSE 0 END)*100.0/COUNT(*) AS DECIMAL(5,2)) AS VARCHAR) + '%',
           CASE WHEN SUM(CASE WHEN geography_sk = -1 THEN 1 ELSE 0 END)*100.0/COUNT(*) < 5
                THEN 'PASS' ELSE 'WARN' END
    FROM mart.fact_order_items;

    PRINT 'Quality checks complete.';
END;
GO



EXEC dq.run_quality_checks;

-- Full results
SELECT check_category, check_name, expected, actual, status
FROM dq.check_results
ORDER BY check_category, check_id;

-- Summary: pass/fail/warn counts
SELECT status, COUNT(*) AS checks
FROM dq.check_results
GROUP BY status;