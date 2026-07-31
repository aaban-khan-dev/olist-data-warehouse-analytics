use OlistDW;
GO

-- BULK LOAD

BULK INSERT staging.customers
FROM 'D:\olist-data-warehouse\data\olist_customers_dataset.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, FIELDTERMINATOR=',',
      ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);
GO

BULK INSERT staging.geolocation
FROM 'D:\olist-data-warehouse\data\olist_geolocation_dataset.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, FIELDTERMINATOR=',',
      ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);
GO

BULK INSERT staging.orders
FROM 'D:\olist-data-warehouse\data\olist_orders_dataset.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, FIELDTERMINATOR=',',
      ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);
GO

BULK INSERT staging.order_items
FROM 'D:\olist-data-warehouse\data\olist_order_items_dataset.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, FIELDTERMINATOR=',',
      ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);
GO

BULK INSERT staging.order_payments
FROM 'D:\olist-data-warehouse\data\olist_order_payments_dataset.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, FIELDTERMINATOR=',',
      ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);
GO

BULK INSERT staging.order_reviews
FROM 'D:\olist-data-warehouse\data\olist_order_reviews_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0d0a',   -- try CRLF this time
    CODEPAGE        = '65001',
    MAXERRORS       = 10,
    TABLOCK
);
GO

BULK INSERT staging.products
FROM 'D:\olist-data-warehouse\data\olist_products_dataset.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, FIELDTERMINATOR=',',
      ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);
GO

BULK INSERT staging.sellers
FROM 'D:\olist-data-warehouse\data\olist_sellers_dataset.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, FIELDTERMINATOR=',',
      ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);
GO

BULK INSERT staging.category_translation
FROM 'D:\olist-data-warehouse\data\product_category_name_translation.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, FIELDTERMINATOR=',',
      ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);
GO

-- verification

SELECT 'customers'            AS table_name, COUNT(*) AS rows FROM staging.customers
UNION ALL SELECT 'geolocation',          COUNT(*) FROM staging.geolocation
UNION ALL SELECT 'orders',               COUNT(*) FROM staging.orders
UNION ALL SELECT 'order_items',          COUNT(*) FROM staging.order_items
UNION ALL SELECT 'order_payments',       COUNT(*) FROM staging.order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM staging.order_reviews
UNION ALL SELECT 'products',             COUNT(*) FROM staging.products
UNION ALL SELECT 'sellers',              COUNT(*) FROM staging.sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM staging.category_translation;

-- accent check
SELECT DISTINCT product_category_name 
FROM staging.products
WHERE product_category_name LIKE '%á%' 
   OR product_category_name LIKE '%ç%'
   OR product_category_name LIKE '%é%'
   OR product_category_name LIKE '%ã%';

-- Review text 
SELECT TOP 5 review_comment_message
FROM staging.order_reviews
WHERE review_comment_message IS NOT NULL
  AND LEN(review_comment_message) > 20;