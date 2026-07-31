# Data Dictionary — Olist Data Warehouse

## Dataset Overview

**Source:** Olist Brazilian E-Commerce Public Dataset (Kaggle)

The source dataset consists of **9 operational tables** covering customer orders placed between **September 2016 and October 2018**.

All source tables are loaded into the **`staging`** schema without modification to preserve source fidelity. Original column names and data types are retained, while constraints and business transformations are applied in downstream warehouse layers.

---

# Staging Tables

## staging.customers

**Grain:** One customer record associated with an order

**Primary Key:** `customer_id`

### Description

Stores customer information used for customer analytics and geographic reporting.

### Key Notes

- `customer_id` identifies a customer within a specific order.
- `customer_unique_id` identifies the actual customer across multiple orders and is used for customer-level analytics such as retention and RFM segmentation.
- Geographic attributes are used to build the Geography dimension.

| Column | Description |
|----------|-------------|
| customer_id | Order-specific customer identifier |
| customer_unique_id | Persistent customer identifier |
| customer_zip_code_prefix | Customer ZIP code prefix |
| customer_city | Customer city |
| customer_state | Customer state |

---

## staging.orders

**Grain:** One record per order

**Primary Key:** `order_id`

### Description

Stores the complete order lifecycle from purchase through delivery.

### Key Notes

- Contains purchase, approval, shipping, delivery, and estimated delivery timestamps.
- Delivery timestamps remain null for orders that were not successfully delivered.

---

## staging.order_items

**Grain:** One record per item within an order

**Primary Key:** (`order_id`, `order_item_id`)

### Description

Stores item-level sales transactions.

### Key Notes

- Contains pricing and freight information.
- Forms the primary fact table of the warehouse.
- Supports product, seller, revenue, and logistics analysis.

---

## staging.order_payments

**Grain:** One payment transaction within an order

**Primary Key:** (`order_id`, `payment_sequential`)

### Description

Stores payment information for customer orders.

### Key Notes

- Multiple payment records may exist for a single order.
- Modeled separately from sales transactions due to its different business grain.

---

## staging.order_reviews

**Grain:** Customer review associated with an order

**Primary Key:** `review_id`

### Description

Stores customer feedback submitted after purchase.

### Key Notes

- Reviews are linked to orders.
- The relationship between orders and reviews is not strictly one-to-one.

---

## staging.products

**Grain:** One record per product

**Primary Key:** `product_id`

### Description

Stores product master information.

### Key Notes

- Original source column names are preserved in staging.
- Product category names are translated during warehouse transformation.

---

## staging.sellers

**Grain:** One record per seller

**Primary Key:** `seller_id`

### Description

Stores seller master information used for marketplace analytics.

### Key Notes

- Serves as the source for the Seller dimension.
- Historical tracking is implemented using Slowly Changing Dimension (Type 2).

---

## staging.geolocation

**Grain:** Geographic coordinate

### Description

Stores latitude and longitude information for Brazilian ZIP code prefixes.

### Key Notes

- Multiple records exist for the same ZIP code prefix.
- Geographic records are consolidated before building the Geography dimension.

---

## staging.category_translation

**Grain:** One category translation

### Description

Maps Portuguese product categories to English.

### Key Notes

- Used during product dimension construction.
- Missing translations are assigned to an **Unknown** member during ETL.


- RFM: Champions + Big Spenders = ~3.5% of customers but spend 1.7-2.2x the average (R$372/R$279 vs R$166 baseline). Large "At Risk" segment reflects the low ~3.4% repeat rate.