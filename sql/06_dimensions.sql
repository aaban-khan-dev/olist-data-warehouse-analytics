use OlistDW;
GO


DROP TABLE IF EXISTS mart.dim_order_status;
GO

CREATE TABLE mart.dim_order_status (
    order_status_sk INT IDENTITY(1,1) PRIMARY KEY,
    order_status    VARCHAR(30) NOT NULL,
    is_delivered    BIT NOT NULL
);
GO

-- Unknown member first, with an explicit key of -1
SET IDENTITY_INSERT mart.dim_order_status ON;
INSERT INTO mart.dim_order_status (order_status_sk, order_status, is_delivered)
VALUES (-1, 'Unknown', 0);
SET IDENTITY_INSERT mart.dim_order_status OFF;
GO

-- Load distinct statuses from staging
INSERT INTO mart.dim_order_status (order_status, is_delivered)
SELECT DISTINCT
    order_status,
    CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END
FROM staging.orders
WHERE order_status IS NOT NULL;
GO

SELECT * FROM mart.dim_order_status;




DROP TABLE IF EXISTS mart.dim_product;
GO

CREATE TABLE mart.dim_product (
    product_sk   INT IDENTITY(1,1) PRIMARY KEY,
    product_id   VARCHAR(50) NOT NULL,
    category_pt  VARCHAR(100) NULL,
    category_en  VARCHAR(100) NULL,
    weight_g     INT NULL,
    length_cm    INT NULL,
    height_cm    INT NULL,
    width_cm     INT NULL
);
GO

-- Unknown member
SET IDENTITY_INSERT mart.dim_product ON;
INSERT INTO mart.dim_product (product_sk, product_id, category_pt, category_en)
VALUES (-1, 'UNKNOWN', 'unknown', 'unknown');
SET IDENTITY_INSERT mart.dim_product OFF;
GO

-- Load products, joining to the English translation.
-- COALESCE handles the 2 categories with no translation → 'unknown'.
INSERT INTO mart.dim_product (product_id, category_pt, category_en, weight_g, length_cm, height_cm, width_cm)
SELECT
    p.product_id,
    p.product_category_name,
    COALESCE(t.product_category_name_english, 'unknown'),
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM staging.products p
LEFT JOIN staging.category_translation t
       ON p.product_category_name = t.product_category_name;
GO

-- Verify: ~32,952 rows (32,951 + unknown). Check the translation worked.
SELECT COUNT(*) AS total FROM mart.dim_product;
SELECT TOP 10 product_id, category_pt, category_en FROM mart.dim_product WHERE category_en <> 'unknown';
SELECT COUNT(*) AS unknown_category_products FROM mart.dim_product WHERE category_en = 'unknown';


DROP TABLE IF EXISTS mart.dim_customer;
GO

CREATE TABLE mart.dim_customer (
    customer_sk        INT IDENTITY(1,1) PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_city      VARCHAR(100) NULL,
    customer_state     VARCHAR(10) NULL,
    rfm_segment        VARCHAR(20) NULL   -- populated in Phase 10
);
GO

-- Unknown member
SET IDENTITY_INSERT mart.dim_customer ON;
INSERT INTO mart.dim_customer (customer_sk, customer_unique_id, customer_city, customer_state)
VALUES (-1, 'UNKNOWN', 'unknown', 'XX');
SET IDENTITY_INSERT mart.dim_customer OFF;
GO

-- Key on customer_unique_id (one row per real person, not per order).
-- A person can appear with different city/state across orders; take the most
-- recent by joining through their latest order. For simplicity we take one
-- representative row per unique_id here.
INSERT INTO mart.dim_customer (customer_unique_id, customer_city, customer_state)
SELECT
    customer_unique_id,
    MAX(customer_city)  AS customer_city,
    MAX(customer_state) AS customer_state
FROM staging.customers
GROUP BY customer_unique_id;
GO

-- Verify: should be ~96,097 rows (96,096 unique + unknown)
SELECT COUNT(*) AS total FROM mart.dim_customer;
SELECT COUNT(DISTINCT customer_unique_id) AS distinct_ids FROM mart.dim_customer;


DROP TABLE IF EXISTS mart.dim_geography;
GO

CREATE TABLE mart.dim_geography (
    geography_sk    INT IDENTITY(1,1) PRIMARY KEY,
    zip_code_prefix VARCHAR(20) NOT NULL,
    city            VARCHAR(100) NULL,
    state           VARCHAR(10) NULL,
    latitude        DECIMAL(18,10) NULL,
    longitude       DECIMAL(18,10) NULL
);
GO

-- Unknown member
SET IDENTITY_INSERT mart.dim_geography ON;
INSERT INTO mart.dim_geography (geography_sk, zip_code_prefix, city, state, latitude, longitude)
VALUES (-1, 'UNKNOWN', 'unknown', 'XX', NULL, NULL);
SET IDENTITY_INSERT mart.dim_geography OFF;
GO

-- Deduplicate: one row per zip. Average the coordinates (centroid of the zip),
-- and take the most frequent city/state for that zip.
WITH zip_coords AS (
    -- Average lat/lng per zip = representative centroid
    SELECT
        geolocation_zip_code_prefix AS zip,
        AVG(geolocation_lat) AS lat,
        AVG(geolocation_lng) AS lng
    FROM staging.geolocation
    GROUP BY geolocation_zip_code_prefix
),
zip_place AS (
    -- Most frequent city/state per zip (ranked by count)
    SELECT
        geolocation_zip_code_prefix AS zip,
        geolocation_city AS city,
        geolocation_state AS state,
        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM staging.geolocation
    GROUP BY geolocation_zip_code_prefix, geolocation_city, geolocation_state
)
INSERT INTO mart.dim_geography (zip_code_prefix, city, state, latitude, longitude)
SELECT
    c.zip,
    p.city,
    p.state,
    c.lat,
    c.lng
FROM zip_coords c
JOIN zip_place p ON c.zip = p.zip AND p.rn = 1;
GO

-- Verify: ~19,016 rows (19,015 zips + unknown)
SELECT COUNT(*) AS total FROM mart.dim_geography;
SELECT COUNT(DISTINCT zip_code_prefix) AS distinct_zips FROM mart.dim_geography;
SELECT TOP 5 * FROM mart.dim_geography WHERE geography_sk > 0;




DROP TABLE IF EXISTS mart.dim_seller;
GO

CREATE TABLE mart.dim_seller (
    seller_sk      INT IDENTITY(1,1) PRIMARY KEY,  -- surrogate; a seller_id can have multiple over time
    seller_id      VARCHAR(50) NOT NULL,           -- natural/business key
    seller_city    VARCHAR(100) NULL,
    seller_state   VARCHAR(10) NULL,
    effective_date DATE NOT NULL,                  -- when this version became active
    expiry_date    DATE NOT NULL,                  -- when it stopped (9999-12-31 = still current)
    is_current     BIT NOT NULL                    -- 1 = latest version
);
GO



-- Unknown member
SET IDENTITY_INSERT mart.dim_seller ON;
INSERT INTO mart.dim_seller (seller_sk, seller_id, seller_city, seller_state, effective_date, expiry_date, is_current)
VALUES (-1, 'UNKNOWN', 'unknown', 'XX', '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT mart.dim_seller OFF;
GO

-- Initial load: every seller enters as the first, current version.
-- effective_date = start of data; expiry far-future; is_current = 1.
INSERT INTO mart.dim_seller (seller_id, seller_city, seller_state, effective_date, expiry_date, is_current)
SELECT
    seller_id,
    seller_city,
    seller_state,
    '2016-01-01' AS effective_date,
    '9999-12-31' AS expiry_date,
    1            AS is_current
FROM staging.sellers;
GO

-- Verify: ~3,096 rows (3,095 + unknown), all current
SELECT COUNT(*) AS total FROM mart.dim_seller;
SELECT is_current, COUNT(*) FROM mart.dim_seller GROUP BY is_current;
SELECT TOP 5 * FROM mart.dim_seller WHERE seller_sk > 0;





-- SCD Type 2 merge logic: detects attribute changes and versions rows.
-- On a real incremental refresh, staging.sellers would contain updated data.
-- For a changed seller: expire the current row, insert a new current version.

-- Step 1: expire current rows whose attributes have changed in the source
UPDATE d
SET d.expiry_date = CAST(GETDATE() AS DATE),
    d.is_current  = 0
FROM mart.dim_seller d
JOIN staging.sellers s ON d.seller_id = s.seller_id
WHERE d.is_current = 1
  AND (ISNULL(d.seller_city,'')  <> ISNULL(s.seller_city,'')
    OR ISNULL(d.seller_state,'') <> ISNULL(s.seller_state,''));

-- Step 2: insert the new current version for those changed sellers
INSERT INTO mart.dim_seller (seller_id, seller_city, seller_state, effective_date, expiry_date, is_current)
SELECT s.seller_id, s.seller_city, s.seller_state, CAST(GETDATE() AS DATE), '9999-12-31', 1
FROM staging.sellers s
WHERE NOT EXISTS (
    SELECT 1 FROM mart.dim_seller d
    WHERE d.seller_id = s.seller_id AND d.is_current = 1
);
GO

-- NOTE: Olist is a static snapshot, so this merge produces no changes on load


SELECT COUNT(*) AS total FROM mart.dim_seller;
SELECT is_current, COUNT(*) AS cnt FROM mart.dim_seller GROUP BY is_current;
SELECT TOP 5 * FROM mart.dim_seller WHERE seller_sk > 0;



SELECT 'order_status' t, COUNT(*) FROM mart.dim_order_status WHERE order_status_sk = -1
UNION ALL SELECT 'product', COUNT(*) FROM mart.dim_product WHERE product_sk = -1
UNION ALL SELECT 'customer', COUNT(*) FROM mart.dim_customer WHERE customer_sk = -1
UNION ALL SELECT 'geography', COUNT(*) FROM mart.dim_geography WHERE geography_sk = -1
UNION ALL SELECT 'seller', COUNT(*) FROM mart.dim_seller WHERE seller_sk = -1
UNION ALL SELECT 'date', COUNT(*) FROM mart.dim_date WHERE date_sk = -1;