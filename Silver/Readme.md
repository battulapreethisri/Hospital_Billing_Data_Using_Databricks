Silver Layer: Silver.sql

The Silver layer cleans the Bronze data and makes it reliable. It creates two tables:

silver_billing_clean removes duplicate bills, trims spaces and fixes capitalisation (INITCAP(TRIM())), replaces blank department and payer values with “Unknown”, fills blank total_amount with quantity × unit_price, and drops rows with an invalid quantity or price using data-quality expectations. It holds 968 clean rows.
silver_billing_rejected stores the rows with a zero or negative quantity, or a negative price, along with a reject_reason. It holds 22 rows.
