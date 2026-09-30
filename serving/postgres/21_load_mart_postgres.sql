-- 21_load_mart_postgres.sql
-- Loads the CSVs exported from SQL Server into the Postgres serving copy.
-- Run from psql as olist_app:
--     psql -h localhost -U olist_app -d olist_dw -f 21_load_mart_postgres.sql
--
-- Source files come from bcp -c -t, which writes no header row and no
-- quoting, hence FORMAT csv with no HEADER option.
--
-- Uses \copy (client-side) rather than COPY (server-side) so the files are
-- read as the logged-in OS user and no postgres-user file permissions are
-- needed. Each \copy must stay on one line -- psql meta-commands are not
-- semicolon-delimited.
--
-- Dimensions load before facts so the foreign keys added at the end validate.

\set csvdir '/home/ubuntu/olist_export'


-- ---------------------------------------------------------------
-- 1. Load
-- ---------------------------------------------------------------

\copy mart.dim_order_status FROM '/home/ubuntu/olist_export/dim_order_status.csv' WITH (FORMAT csv)
\copy mart.dim_product FROM '/home/ubuntu/olist_export/dim_product.csv' WITH (FORMAT csv)
\copy mart.dim_customer FROM '/home/ubuntu/olist_export/dim_customer.csv' WITH (FORMAT csv)
\copy mart.dim_geography FROM '/home/ubuntu/olist_export/dim_geography.csv' WITH (FORMAT csv)
\copy mart.dim_seller FROM '/home/ubuntu/olist_export/dim_seller.csv' WITH (FORMAT csv)
\copy mart.dim_date FROM '/home/ubuntu/olist_export/dim_date.csv' WITH (FORMAT csv)
\copy mart.fact_order_items FROM '/home/ubuntu/olist_export/fact_order_items.csv' WITH (FORMAT csv)
\copy mart.fact_delivery_reviews FROM '/home/ubuntu/olist_export/fact_delivery_reviews.csv' WITH (FORMAT csv)


-- ---------------------------------------------------------------
-- 2. Empty string -> NULL
--
-- Defensive. bcp -c writes NULL as a truly empty unquoted field, which
-- Postgres CSV mode already reads as NULL, so these normally match zero
-- rows. They are kept so the script stays correct if the export is ever
-- redone with a tool that quotes empty strings instead.
-- ---------------------------------------------------------------

UPDATE mart.dim_product   SET category_pt    = NULL WHERE category_pt    = '';
UPDATE mart.dim_product   SET category_en    = NULL WHERE category_en    = '';
UPDATE mart.dim_customer  SET customer_city  = NULL WHERE customer_city  = '';
UPDATE mart.dim_customer  SET customer_state = NULL WHERE customer_state = '';
UPDATE mart.dim_customer  SET rfm_segment    = NULL WHERE rfm_segment    = '';
UPDATE mart.dim_geography SET city           = NULL WHERE city           = '';
UPDATE mart.dim_geography SET state          = NULL WHERE state          = '';
UPDATE mart.dim_seller    SET seller_city    = NULL WHERE seller_city    = '';
UPDATE mart.dim_seller    SET seller_state   = NULL WHERE seller_state   = '';
UPDATE mart.dim_date      SET holiday_name   = NULL WHERE holiday_name   = '';


-- ---------------------------------------------------------------
-- 3. Reset identity sequences
--
-- The surrogate keys arrived as explicit values, so each identity sequence
-- is still at 1 and the next insert would collide. Advance each to the
-- current maximum.
-- ---------------------------------------------------------------

SELECT setval(pg_get_serial_sequence('mart.dim_order_status','order_status_sk'),
              GREATEST((SELECT MAX(order_status_sk) FROM mart.dim_order_status), 1));
SELECT setval(pg_get_serial_sequence('mart.dim_product','product_sk'),
              GREATEST((SELECT MAX(product_sk) FROM mart.dim_product), 1));
SELECT setval(pg_get_serial_sequence('mart.dim_customer','customer_sk'),
              GREATEST((SELECT MAX(customer_sk) FROM mart.dim_customer), 1));
SELECT setval(pg_get_serial_sequence('mart.dim_geography','geography_sk'),
              GREATEST((SELECT MAX(geography_sk) FROM mart.dim_geography), 1));
SELECT setval(pg_get_serial_sequence('mart.dim_seller','seller_sk'),
              GREATEST((SELECT MAX(seller_sk) FROM mart.dim_seller), 1));
SELECT setval(pg_get_serial_sequence('mart.fact_order_items','order_item_sk'),
              GREATEST((SELECT MAX(order_item_sk) FROM mart.fact_order_items), 1));
SELECT setval(pg_get_serial_sequence('mart.fact_delivery_reviews','delivery_review_sk'),
              GREATEST((SELECT MAX(delivery_review_sk) FROM mart.fact_delivery_reviews), 1));


-- ---------------------------------------------------------------
-- 4. Foreign keys
--
-- Added after load rather than before: creating them up front would force a
-- per-row check during COPY. Creating them here validates every fact row in
-- one pass and proves the star's referential integrity survived the port.
-- ---------------------------------------------------------------

ALTER TABLE mart.fact_order_items
    ADD CONSTRAINT fk_foi_date     FOREIGN KEY (date_sk)         REFERENCES mart.dim_date(date_sk),
    ADD CONSTRAINT fk_foi_product  FOREIGN KEY (product_sk)      REFERENCES mart.dim_product(product_sk),
    ADD CONSTRAINT fk_foi_seller   FOREIGN KEY (seller_sk)       REFERENCES mart.dim_seller(seller_sk),
    ADD CONSTRAINT fk_foi_customer FOREIGN KEY (customer_sk)     REFERENCES mart.dim_customer(customer_sk),
    ADD CONSTRAINT fk_foi_geo      FOREIGN KEY (geography_sk)    REFERENCES mart.dim_geography(geography_sk),
    ADD CONSTRAINT fk_foi_status   FOREIGN KEY (order_status_sk) REFERENCES mart.dim_order_status(order_status_sk);

ALTER TABLE mart.fact_delivery_reviews
    ADD CONSTRAINT fk_fdr_customer FOREIGN KEY (customer_sk)      REFERENCES mart.dim_customer(customer_sk),
    ADD CONSTRAINT fk_fdr_status   FOREIGN KEY (order_status_sk)  REFERENCES mart.dim_order_status(order_status_sk),
    ADD CONSTRAINT fk_fdr_date     FOREIGN KEY (purchase_date_sk) REFERENCES mart.dim_date(date_sk);


-- ---------------------------------------------------------------
-- 5. Planner statistics
--
-- No indexes are created here on purpose. The indexing pass is done
-- separately with EXPLAIN ANALYZE timings recorded before and after.
-- ---------------------------------------------------------------

ANALYZE;
