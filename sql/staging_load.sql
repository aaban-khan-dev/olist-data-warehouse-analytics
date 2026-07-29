use OlistDW;
GO


USE OlistDW;
GO

-- for clean Rerun
DROP TABLE IF EXISTS staging.customers;
DROP TABLE IF EXISTS staging.geolocation;
DROP TABLE IF EXISTS staging.orders;
DROP TABLE IF EXISTS staging.order_items;
DROP TABLE IF EXISTS staging.order_payments;
DROP TABLE IF EXISTS staging.order_reviews;
DROP TABLE IF EXISTS staging.products;
DROP TABLE IF EXISTS staging.sellers;
DROP TABLE IF EXISTS staging.category_translation;
GO

CREATE TABLE staging.customers (
    customer_id               VARCHAR(50)  NULL,
    customer_unique_id        VARCHAR(50)  NULL,
    customer_zip_code_prefix  VARCHAR(20)  NULL,
    customer_city             VARCHAR(100) NULL,
    customer_state            VARCHAR(10)  NULL
);
GO

CREATE TABLE staging.geolocation (
    geolocation_zip_code_prefix VARCHAR(20)   NULL,
    geolocation_lat             DECIMAL(18,10) NULL,
    geolocation_lng             DECIMAL(18,10) NULL,
    geolocation_city            VARCHAR(100)  NULL,
    geolocation_state           VARCHAR(10)   NULL
);
GO

CREATE TABLE staging.orders (
    order_id                      VARCHAR(50) NULL,
    customer_id                   VARCHAR(50) NULL,
    order_status                  VARCHAR(30) NULL,
    order_purchase_timestamp      VARCHAR(30) NULL,
    order_approved_at             VARCHAR(30) NULL,
    order_delivered_carrier_date  VARCHAR(30) NULL,
    order_delivered_customer_date VARCHAR(30) NULL,
    order_estimated_delivery_date VARCHAR(30) NULL
);
GO

CREATE TABLE staging.order_items (
    order_id            VARCHAR(50)   NULL,
    order_item_id       INT           NULL,
    product_id          VARCHAR(50)   NULL,
    seller_id           VARCHAR(50)   NULL,
    shipping_limit_date VARCHAR(30)   NULL,
    price               DECIMAL(18,2) NULL,
    freight_value       DECIMAL(18,2) NULL
);
GO

CREATE TABLE staging.order_payments (
    order_id             VARCHAR(50)   NULL,
    payment_sequential   INT           NULL,
    payment_type         VARCHAR(30)   NULL,
    payment_installments INT           NULL,
    payment_value        DECIMAL(18,2) NULL
);
GO

CREATE TABLE staging.order_reviews (
    review_id               VARCHAR(50)  NULL,
    order_id                VARCHAR(50)  NULL,
    review_score            INT          NULL,
    review_comment_title    VARCHAR(255) NULL,
    review_comment_message  VARCHAR(MAX) NULL,
    review_creation_date    VARCHAR(30)  NULL,
    review_answer_timestamp VARCHAR(30)  NULL
);
GO

CREATE TABLE staging.products (
    product_id                 VARCHAR(50)  NULL,
    product_category_name      VARCHAR(100) NULL,
    product_name_lenght        INT          NULL,
    product_description_lenght INT          NULL,
    product_photos_qty         INT          NULL,
    product_weight_g           INT          NULL,
    product_length_cm          INT          NULL,
    product_height_cm          INT          NULL,
    product_width_cm           INT          NULL
);
GO

CREATE TABLE staging.sellers (
    seller_id               VARCHAR(50)  NULL,
    seller_zip_code_prefix  VARCHAR(20)  NULL,
    seller_city             VARCHAR(100) NULL,
    seller_state            VARCHAR(10)  NULL
);
GO

CREATE TABLE staging.category_translation (
    product_category_name         VARCHAR(100) NULL,
    product_category_name_english VARCHAR(100) NULL
);
GO