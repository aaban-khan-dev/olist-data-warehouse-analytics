# Star Schema Design — Olist Data Warehouse

## Schema Overview

The warehouse follows a **star schema** to support analytical workloads and business intelligence reporting. A denormalized dimensional model was chosen to simplify analytical queries, improve Power BI performance, and provide an intuitive structure for reporting and dashboard development.

### Why Star Schema?

- Optimized for OLAP workloads and business reporting
- Reduced join complexity compared to a snowflake schema
- Improved query performance for analytical SQL and Power BI
- Simplified data model for business users and analysts

---

# Fact Tables

## fact_order_items

**Grain:** One row per order item (`order_id + order_item_id`)

The primary fact table that stores item-level sales transactions.

### Measures

- Price
- Freight Value
- Freight Percentage (derived)
- Net Contribution (`price - freight_value`)

### Purpose

The item-level grain preserves detailed pricing and freight information required for revenue analysis, freight-cost analysis, product performance, and profitability proxy metrics.

---

## fact_payments

**Grain:** One row per payment transaction (`order_id + payment_sequential`)

Stores payment information independently of sales transactions.

### Measures

- Payment Value
- Payment Installments

### Purpose

Payments occur at a different grain than order items. Maintaining a separate fact table prevents duplicate records while supporting payment behavior and installment analysis.

---

# Dimension Tables

| Dimension | Grain | Description |
|-----------|-------|-------------|
| **dim_date** | One calendar day | Date dimension containing calendar attributes for time-based analysis. |
| **dim_customer** | One unique customer | Uses `customer_unique_id` to support customer-level analytics such as retention and RFM segmentation. |
| **dim_product** | One product | Product master with English category names. Missing translations are mapped to an **Unknown** member during ETL. |
| **dim_seller** | One seller version | Implements Slowly Changing Dimension (Type 2) to preserve seller history. |
| **dim_geography** | One ZIP code prefix | Geographic dimension supporting regional, logistics, and delivery analysis. |
| **dim_order_status** | One order status | Stores the order lifecycle with delivery status indicators for operational reporting. |

---

# Warehouse Design Patterns

## Surrogate Keys

All dimension tables use integer surrogate keys (`*_sk`) to:

- Improve join performance
- Decouple warehouse keys from source system identifiers
- Support Slowly Changing Dimensions (Type 2)

---

## Unknown Members

Each dimension contains an **Unknown** record (`*_sk = -1`).

This ensures that fact records with missing or unmatched dimension values are retained during ETL instead of being discarded.

---

## Slowly Changing Dimension (Type 2)

The **Seller** dimension is implemented as an SCD Type 2 table to preserve historical changes over time using effective date, expiry date, and current-record indicators.

---

## Conformed Dimensions

Shared dimensions such as **Date**, **Customer**, and **Order Status** are reused across multiple fact tables to provide consistent reporting throughout the warehouse.

---

# Data Model Summary

| Component | Count |
|-----------|------:|
| Fact Tables | 2 |
| Dimension Tables | 6 |
| Schema Type | Star Schema |
| Primary Business Process | Order Sales |
| Primary Grain | Order Item |
| Secondary Grain | Payment Transaction |