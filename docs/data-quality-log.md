# Data Quality Log — Olist Warehouse

| # | Issue | Evidence | Impact | Resolution |
|---|---|---|---|---|
| 1 | customer_id not stable per person | 99,441 customer_id vs 96,096 customer_unique_id | RFM would miss all repeat customers | Key customer analysis on customer_unique_id |
| 2 | geolocation multi-valued per zip | 1,000,163 rows, 19,015 distinct zips | Joins would fan out ~53x | Deduplicate to 1 lat/lng per zip in dim_geography |
| 3 | Orders without reviews | 768 orders unmatched | Fact rows with no review | Route to unknown review member (-1) |
| 4 | Order without payment | 1 order unmatched | Missing payment fact | Route to unknown / flag |
| 5 | Categories without translation | 2 categories | Null English names in dim_product | Map to 'unknown'/keep Portuguese fallback |
| 6 | Duplicate review_ids / multi-review orders | 99,224 rows, 98,410 review_ids, 98,673 orders | Review not 1:1 with order | Dedupe or take latest review per order |
| 7 | Null delivery timestamps | Correlated with canceled/unavailable status | Delivery analysis skew | Scope delivery analysis to delivered orders |
| 8 | Source column misspellings ("lenght") | products file | Confusing names | Rename in intermediate layer |
| 9 | Sparse 2016 + partial 2018 tail | 2016-09: 4 orders, 2016-12: 1; 2018-09: 16, 2018-10: 4 | Skews any full-range trend | Scope trend analysis to Jan 2017–Aug 2018 |
| 10 | Non-delivered orders lack delivery dates | 97.0% delivered; ~3% canceled/unavailable/shipped | Null delivery timestamps | Scope delivery-vs-review analysis to delivered orders |