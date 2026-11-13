Gold Layer: Gold.sql

The Gold layer builds business-ready summary tables from the clean data only:

gold_monthly_revenue gives revenue, insurance amount and visits per month.
gold_department_summary gives visits, bills, revenue and average revenue per visit by department.
gold_branch_summary gives visits and revenue by region, city and branch.
gold_payer_summary gives revenue, insurance amount and pending amount by payer type.
gold_data_quality counts each data problem and checks the reconciliation: Bronze rows (1,010) = clean (968) + rejected (22) + duplicates (20).
