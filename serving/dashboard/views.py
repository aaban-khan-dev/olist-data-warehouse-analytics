"""
Freight Analysis page.

Two query styles, used deliberately:

  * The filter dropdowns are built with the Django ORM. They are simple
    DISTINCT lookups over single dimensions, which is exactly what the ORM is
    good at, and it keeps the option lists tied to the models.

  * The KPIs and the four charts are raw SQL through connection.cursor().
    They are star-schema aggregates joining a 112k-row fact to three
    dimensions, with the same SUM(freight)/SUM(price) ratio computed at four
    different grains. Expressing that through the ORM would mean fighting it
    over GROUP BY placement and would generate worse SQL than writing it
    directly.

Every filter value reaches the database as a bound parameter, never as string
interpolation.

Freight % of revenue is SUM(freight_value) / SUM(price) -- the ratio of the
totals, matching the Power BI measure DIVIDE([Total Freight], [Total Revenue]).
It is not the average of the per-row freight_pct column: that would weight a
R$5 item the same as a R$500 one and gives a materially different answer.
"""

import json

from django.db import connection
from django.shortcuts import render

from .models import DimDate, DimGeography, DimProduct

# Joins shared by every aggregate on this page.
BASE_FROM = """
    FROM mart.fact_order_items f
    JOIN mart.dim_date      d ON f.date_sk      = d.date_sk
    JOIN mart.dim_product   p ON f.product_sk   = p.product_sk
    JOIN mart.dim_geography g ON f.geography_sk = g.geography_sk
"""


def _filters(request):
    """Read the query string into a (where_sql, params, selected) triple."""
    year = request.GET.get('year') or ''
    state = request.GET.get('state') or ''
    category = request.GET.get('category') or ''

    clauses, params = [], []
    if year:
        clauses.append("d.year = %s")
        params.append(int(year))
    if state:
        clauses.append("g.state = %s")
        params.append(state)
    if category:
        clauses.append("p.category_en = %s")
        params.append(category)

    where = (" WHERE " + " AND ".join(clauses)) if clauses else ""
    selected = {'year': year, 'state': state, 'category': category}
    return where, params, selected


def _rows(sql, params):
    with connection.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()

def _compact(v):
    """13591643.70 -> '13.59M'. Matches the Power BI card formatting."""
    v = float(v or 0)
    if abs(v) >= 1_000_000:
        return f"{v / 1_000_000:.2f}M"
    if abs(v) >= 1_000:
        return f"{v / 1_000:.1f}K"
    return f"{v:,.2f}"


def freight_analysis(request):
    where, params, selected = _filters(request)

    # ---- KPI strip -------------------------------------------------
    kpi_sql = f"""
        SELECT
            COALESCE(SUM(f.price), 0)                                  AS total_revenue,
            COALESCE(SUM(f.freight_value), 0)                          AS total_freight,
            CASE WHEN SUM(f.price) > 0
                 THEN SUM(f.freight_value) / SUM(f.price) END          AS freight_pct,
            AVG(f.freight_value)                                       AS avg_freight_per_item,
            COUNT(*)                                                   AS item_count
        {BASE_FROM}
        {where}
    """
    revenue, freight, pct, avg_freight, item_count = _rows(kpi_sql, params)[0]

    kpis = {
        'total_revenue': float(revenue or 0),
        'total_freight': float(freight or 0),
        'freight_pct': float(pct or 0) * 100,
        'avg_freight_per_item': float(avg_freight or 0),
        'item_count': item_count,
        'total_revenue_fmt': _compact(revenue),
        'total_freight_fmt': _compact(freight),
    }

    # ---- Freight % over time ---------------------------------------
    # date_sk = -1 is the Unknown member (full_date 1900-01-01) and is
    # excluded so it does not anchor the axis three decades to the left.
    trend_where = where + (" AND " if where else " WHERE ") + "f.date_sk <> -1"
    trend_sql = f"""
        SELECT d.year, d.month,
               SUM(f.freight_value) / NULLIF(SUM(f.price), 0) AS pct
        {BASE_FROM}
        {trend_where}
        GROUP BY d.year, d.month
        HAVING COUNT(*) >= 30
        ORDER BY d.year, d.month
    """
    trend = _rows(trend_sql, params)
    trend_labels = [f"{y}-{m:02d}" for y, m, _ in trend]
    trend_values = [float(p) * 100 for _, _, p in trend]

    # ---- Top categories by freight % -------------------------------
    # The Unknown product member and unmapped categories are dropped; a
    # revenue floor keeps one-off categories with a handful of items from
    # topping the chart on noise.
    cat_where = where + (" AND " if where else " WHERE ") + \
        "f.product_sk <> -1 AND p.category_en IS NOT NULL AND p.category_en <> 'unknown'"
    cat_sql = f"""
        SELECT p.category_en,
               SUM(f.freight_value) / NULLIF(SUM(f.price), 0) AS pct
        {BASE_FROM}
        {cat_where}
        GROUP BY p.category_en
        HAVING SUM(f.price) >= 1000
        ORDER BY pct DESC
        LIMIT 10
    """
    cats = _rows(cat_sql, params)
    cat_labels = [c for c, _ in cats]
    cat_values = [float(p) * 100 for _, p in cats]

    # ---- Revenue share by category ---------------------------------
    rev_sql = f"""
        SELECT p.category_en, SUM(f.price) AS revenue
        {BASE_FROM}
        {cat_where}
        GROUP BY p.category_en
        ORDER BY revenue DESC
        LIMIT 6
    """
    revs = _rows(rev_sql, params)
    rev_labels = [c for c, _ in revs]
    rev_values = [float(v) for _, v in revs]

    # ---- Top states by freight % -----------------------------------
    state_where = where + (" AND " if where else " WHERE ") + \
        "f.geography_sk <> -1 AND g.state IS NOT NULL AND g.state <> 'XX'"
    state_sql = f"""
        SELECT g.state,
               SUM(f.freight_value) / NULLIF(SUM(f.price), 0) AS pct
        {BASE_FROM}
        {state_where}
        GROUP BY g.state
        HAVING SUM(f.price) > 0
        ORDER BY pct DESC
        LIMIT 10
    """
    states = _rows(state_sql, params)
    state_labels = [s for s, _ in states]
    state_values = [float(p) * 100 for _, p in states]

    # ---- Filter options (ORM) --------------------------------------
    years = (DimDate.objects.exclude(date_sk=-1)
             .values_list('year', flat=True).distinct().order_by('year'))
    state_opts = (DimGeography.objects.exclude(geography_sk=-1)
                  .exclude(state__isnull=True).exclude(state='XX')
                  .values_list('state', flat=True).distinct().order_by('state'))
    category_opts = (DimProduct.objects.exclude(product_sk=-1)
                     .exclude(category_en__isnull=True).exclude(category_en='unknown')
                     .values_list('category_en', flat=True).distinct().order_by('category_en'))

    context = {
        'kpis': kpis,
        'selected': selected,
        'years': list(years),
        'state_opts': list(state_opts),
        'category_opts': list(category_opts),
        'charts': json.dumps({
            'trend': {'labels': trend_labels, 'values': trend_values},
            'categories': {'labels': cat_labels, 'values': cat_values},
            'revenue': {'labels': rev_labels, 'values': rev_values},
            'states': {'labels': state_labels, 'values': state_values},
        }),
        'has_filters': bool(where),
    }
    return render(request, 'dashboard/freight.html', context)
