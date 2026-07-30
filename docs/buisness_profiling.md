# Business Profiling — Olist Data Warehouse

## Overview

This document summarizes the key business characteristics identified during exploratory data profiling. These insights guided the dimensional model design and helped prioritize analytical use cases implemented in the warehouse.

---

# Revenue & Freight Profile

## Revenue Distribution

- Total sales revenue: **R$13,591,643.70**
- Total freight charged: **R$2,251,909.54**
- Freight accounts for **16.57%** of total sales revenue.

### Key Insights

- Freight represents a significant operational cost across the marketplace.
- Approximately **17%** of order items have freight costs exceeding **50%** of the item price.
- More than **4,000** products have freight costs higher than the product price itself.

These findings motivated the Freight Cost Analysis included in the warehouse.

---

# Order Profile

## Order Composition

- Total orders: **99,441**
- Total order items: **112,650**
- Average items per order: **1.14**

### Key Insights

- The marketplace is predominantly composed of single-item purchases.
- Only **9.9%** of orders contain multiple products.

This validates using **order items** as the primary analytical grain.

---

# Customer Profile

## Customer Purchasing Behavior

- Total customer records: **99,441**
- Unique customers: **96,096**
- Repeat customers: **3,345**

### Key Insights

- The majority of customers placed only one order.
- Customer retention is relatively low, making RFM segmentation and repeat purchase analysis valuable business use cases.

---

# Time Profile

## Data Coverage

The dataset spans **September 2016 through October 2018**.

### Key Insights

- Early months contain very few transactions.
- The final months contain only partial data.
- The primary analytical period is **January 2017 – August 2018**, providing the most representative business activity.

---

# Order Fulfillment Profile

## Delivery Performance

- Delivered orders: **96,478**
- Overall delivery rate: **97.0%**

### Key Insights

- Most marketplace transactions are successfully completed.
- Delivery delay analysis is restricted to delivered orders to ensure accurate transit time calculations.

---

# Key Business Takeaways

The profiling phase identified several analytical opportunities that directly influenced the warehouse design:

- Freight is a major cost component and a strong candidate for profitability analysis.
- Customer retention is relatively low, supporting customer segmentation and RFM analysis.
- Order items provide the most appropriate grain for sales analytics.
- Delivery performance can be evaluated reliably using the high proportion of completed orders.
- The dataset provides approximately twenty months of representative business activity suitable for trend analysis.