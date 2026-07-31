Use OlistDW;
GO

-- check for expected rows
SELECT 'dim_date' tbl, COUNT(*) rows FROM mart.dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM mart.dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM mart.dim_product
UNION ALL SELECT 'dim_seller', COUNT(*) FROM mart.dim_seller
UNION ALL SELECT 'dim_geography', COUNT(*) FROM mart.dim_geography
UNION ALL SELECT 'dim_order_status', COUNT(*) FROM mart.dim_order_status
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM mart.fact_order_items
UNION ALL SELECT 'fact_payments', COUNT(*) FROM mart.fact_payments
ORDER BY tbl;


-- check for -1 unknown member
SELECT 'date' d, COUNT(*) has_unknown FROM mart.dim_date WHERE date_sk = -1
UNION ALL SELECT 'customer', COUNT(*) FROM mart.dim_customer WHERE customer_sk = -1
UNION ALL SELECT 'product', COUNT(*) FROM mart.dim_product WHERE product_sk = -1
UNION ALL SELECT 'seller', COUNT(*) FROM mart.dim_seller WHERE seller_sk = -1
UNION ALL SELECT 'geography', COUNT(*) FROM mart.dim_geography WHERE geography_sk = -1
UNION ALL SELECT 'order_status', COUNT(*) FROM mart.dim_order_status WHERE order_status_sk = -1;


-- no fact points to a missing dimension key
-- Should all return 0
SELECT 'oi_bad_product' chk, COUNT(*) bad FROM mart.fact_order_items f
  LEFT JOIN mart.dim_product d ON f.product_sk=d.product_sk WHERE d.product_sk IS NULL
UNION ALL SELECT 'oi_bad_seller', COUNT(*) FROM mart.fact_order_items f
  LEFT JOIN mart.dim_seller d ON f.seller_sk=d.seller_sk WHERE d.seller_sk IS NULL
UNION ALL SELECT 'oi_bad_customer', COUNT(*) FROM mart.fact_order_items f
  LEFT JOIN mart.dim_customer d ON f.customer_sk=d.customer_sk WHERE d.customer_sk IS NULL
UNION ALL SELECT 'oi_bad_geo', COUNT(*) FROM mart.fact_order_items f
  LEFT JOIN mart.dim_geography d ON f.geography_sk=d.geography_sk WHERE d.geography_sk IS NULL
UNION ALL SELECT 'oi_bad_date', COUNT(*) FROM mart.fact_order_items f
  LEFT JOIN mart.dim_date d ON f.date_sk=d.date_sk WHERE d.date_sk IS NULL
UNION ALL SELECT 'oi_bad_status', COUNT(*) FROM mart.fact_order_items f
  LEFT JOIN mart.dim_order_status d ON f.order_status_sk=d.order_status_sk WHERE d.order_status_sk IS NULL
UNION ALL SELECT 'pay_bad_customer', COUNT(*) FROM mart.fact_payments f
  LEFT JOIN mart.dim_customer d ON f.customer_sk=d.customer_sk WHERE d.customer_sk IS NULL
UNION ALL SELECT 'pay_bad_date', COUNT(*) FROM mart.fact_payments f
  LEFT JOIN mart.dim_date d ON f.date_sk=d.date_sk WHERE d.date_sk IS NULL;


-- no null in RFM check
  SELECT
    SUM(CASE WHEN rfm_segment IS NULL THEN 1 ELSE 0 END) AS null_segments,
    COUNT(DISTINCT rfm_segment) AS distinct_segments
FROM mart.dim_customer;



-- DQ suite check
EXEC dq.run_quality_checks;
SELECT status, COUNT(*) FROM dq.check_results GROUP BY status;

