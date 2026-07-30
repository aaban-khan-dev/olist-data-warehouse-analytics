# Data Dictionary — Olist E-Commerce Warehouse

Source: Olist Brazilian E-Commerce (Kaggle, olistbr). 9 tables, orders Sept 2016–Oct 2018.
All tables loaded to `staging` schema as-is (permissive types, nullable, no constraints).

## staging.customers
- **Rows:** 99,441 | **Grain:** one row per order-customer | **PK:** customer_id
- **Key finding:** customer_id is unique per order (99,441), but customer_unique_id has only 96,096 distinct values → 3,345 repeat customers. Use customer_unique_id for customer-level analysis (RFM).

| Column | Notes |
|---|---|
| customer_id | Unique per order; FK from orders |
| customer_unique_id | Stable per real customer; use for retention/RFM |
| customer_zip_code_prefix | Joins to geolocation |
| customer_city, customer_state | Location |

## staging.orders
- **Rows:** 99,441 | **Grain:** one row per order | **PK:** order_id (fully unique)
- Timestamps: purchase, approved, delivered_carrier, delivered_customer, estimated_delivery.
- Delivery timestamps null for non-delivered statuses (canceled/unavailable).

## staging.order_items
- **Rows:** 112,650 | **Grain:** one row per item line within an order | **PK:** order_id + order_item_id
- 98,666 distinct orders → avg ~1.14 items/order. Holds price and freight_value (core revenue/freight columns).

## staging.order_payments
- **Rows:** 103,886 | **Grain:** one row per payment sequence within an order | **PK:** order_id + payment_sequential
- Fully unique on composite key. One order can have multiple payment records.

## staging.order_reviews
- **Rows:** 99,224 | **Grain:** ~one review per order | **PK:** review_id (98,410 distinct — minor dupes)
- 98,673 distinct orders → some orders have multiple reviews; review not strictly 1:1 with order.

## staging.products
- **Rows:** 32,951 | **Grain:** one row per product | **PK:** product_id (fully unique)
- Source misspellings "lenght" retained in staging (fidelity); fixed in intermediate layer.

## staging.sellers
- **Rows:** 3,095 | **Grain:** one row per seller | **PK:** seller_id (fully unique)

## staging.geolocation
- **Rows:** 1,000,163 | **Distinct zips:** 19,015 (~53 points/zip)
- **Must deduplicate** to one representative lat/lng per zip before dim_geography.

## staging.category_translation
- **Rows:** 71 | Portuguese→English category names. 2 product categories have no translation.

## Profiling Insights (business shape)

**Revenue & freight**
- Total revenue: R$13,591,643.70 | Total freight: R$2,251,909.54
- Freight = 16.57% of revenue overall — high for e-commerce; anchors the freight-margin analysis
- 18,941 items (~17%) have freight > 50% of item price; 4,124 items have freight exceeding the price entirely

**Order composition**
- Avg 1.14 items per order; only 9.9% of orders are multi-item — predominantly single-item marketplace
- 3,345 repeat customers (99,441 orders vs 96,096 unique) — ~3.4% repeat rate

**Time coverage**
- Data spans 2016-09 to 2018-10, but 2016 is near-empty (Sep: 4, Dec: 1 order) and both 2018 tail months are partial (Sep: 16, Oct: 4)
- Effective analytical window: Jan 2017 – Aug 2018

**Order fulfillment**
- 97.0% of orders delivered (96,478 of 99,441); remainder canceled/unavailable/shipped/etc.
- Delivery analysis will be scoped to delivered orders only