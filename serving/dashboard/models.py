"""
Models for the Olist mart, generated with `manage.py inspectdb` against the
PostgreSQL serving copy and then cleaned up.

Every model is `managed = False`. The warehouse is built and loaded by the SQL
in sql/ and serving/postgres/; Django only reads it. Marking the models
unmanaged means makemigrations will never try to alter or drop these tables.

Table names carry no schema prefix because the connection sets
search_path=mart,public (see config/settings.py).
"""

from django.db import models


# ---------------------------------------------------------------
# Dimensions
# ---------------------------------------------------------------

class DimDate(models.Model):
    date_sk = models.IntegerField(primary_key=True)
    full_date = models.DateField()
    year = models.IntegerField()
    quarter = models.IntegerField()
    month = models.IntegerField()
    month_name = models.CharField(max_length=20)
    day = models.IntegerField()
    weekday_name = models.CharField(max_length=20)
    is_weekend = models.BooleanField()
    is_holiday = models.BooleanField()
    holiday_name = models.CharField(max_length=50, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'dim_date'

    def __str__(self):
        return str(self.full_date)


class DimProduct(models.Model):
    product_sk = models.AutoField(primary_key=True)
    product_id = models.CharField(max_length=50)
    category_pt = models.CharField(max_length=100, blank=True, null=True)
    category_en = models.CharField(max_length=100, blank=True, null=True)
    weight_g = models.IntegerField(blank=True, null=True)
    length_cm = models.IntegerField(blank=True, null=True)
    height_cm = models.IntegerField(blank=True, null=True)
    width_cm = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'dim_product'

    def __str__(self):
        return self.category_en or self.product_id


class DimCustomer(models.Model):
    customer_sk = models.AutoField(primary_key=True)
    customer_unique_id = models.CharField(max_length=50)
    customer_city = models.CharField(max_length=100, blank=True, null=True)
    customer_state = models.CharField(max_length=10, blank=True, null=True)
    rfm_segment = models.CharField(max_length=20, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'dim_customer'


class DimGeography(models.Model):
    geography_sk = models.AutoField(primary_key=True)
    zip_code_prefix = models.CharField(max_length=20)
    city = models.CharField(max_length=100, blank=True, null=True)
    state = models.CharField(max_length=10, blank=True, null=True)
    latitude = models.DecimalField(max_digits=18, decimal_places=10, blank=True, null=True)
    longitude = models.DecimalField(max_digits=18, decimal_places=10, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'dim_geography'


class DimSeller(models.Model):
    seller_sk = models.AutoField(primary_key=True)
    seller_id = models.CharField(max_length=50)
    seller_city = models.CharField(max_length=100, blank=True, null=True)
    seller_state = models.CharField(max_length=10, blank=True, null=True)
    effective_date = models.DateField()
    expiry_date = models.DateField()
    is_current = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'dim_seller'


class DimOrderStatus(models.Model):
    order_status_sk = models.AutoField(primary_key=True)
    order_status = models.CharField(max_length=30)
    is_delivered = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'dim_order_status'

    def __str__(self):
        return self.order_status


# ---------------------------------------------------------------
# Facts
# ---------------------------------------------------------------

class FactOrderItems(models.Model):
    order_item_sk = models.AutoField(primary_key=True)
    order_id = models.CharField(max_length=50)
    order_item_id = models.IntegerField()
    date_sk = models.ForeignKey(DimDate, models.DO_NOTHING, db_column='date_sk')
    product_sk = models.ForeignKey(DimProduct, models.DO_NOTHING, db_column='product_sk')
    seller_sk = models.ForeignKey(DimSeller, models.DO_NOTHING, db_column='seller_sk')
    customer_sk = models.ForeignKey(DimCustomer, models.DO_NOTHING, db_column='customer_sk')
    geography_sk = models.ForeignKey(DimGeography, models.DO_NOTHING, db_column='geography_sk')
    order_status_sk = models.ForeignKey(DimOrderStatus, models.DO_NOTHING, db_column='order_status_sk')
    price = models.DecimalField(max_digits=18, decimal_places=2, blank=True, null=True)
    freight_value = models.DecimalField(max_digits=18, decimal_places=2, blank=True, null=True)
    freight_pct = models.DecimalField(max_digits=9, decimal_places=4, blank=True, null=True)
    net_contribution = models.DecimalField(max_digits=18, decimal_places=2, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'fact_order_items'


class FactDeliveryReviews(models.Model):
    delivery_review_sk = models.AutoField(primary_key=True)
    order_id = models.CharField(max_length=50)
    customer_sk = models.ForeignKey(DimCustomer, models.DO_NOTHING, db_column='customer_sk')
    order_status_sk = models.ForeignKey(DimOrderStatus, models.DO_NOTHING, db_column='order_status_sk')
    purchase_date_sk = models.ForeignKey(DimDate, models.DO_NOTHING, db_column='purchase_date_sk')
    review_score = models.IntegerField(blank=True, null=True)
    estimated_days = models.IntegerField(blank=True, null=True)
    actual_days = models.IntegerField(blank=True, null=True)
    delivery_delay_days = models.IntegerField(blank=True, null=True)
    is_late = models.BooleanField(blank=True, null=True)
    is_delivered = models.BooleanField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'fact_delivery_reviews'
