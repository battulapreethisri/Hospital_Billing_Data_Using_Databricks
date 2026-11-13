# Dashboards

This folder holds the Databricks AI/BI dashboard for the Hospital Billing Analytics project.

## Files

| File | Description |
|---|---|
| `Hospital_Billing_Analytics.pdf` | PDF export of the published dashboard |
| `screenshots/` | Screenshots of each dashboard page |

## Dashboard Overview

- **Tool:** Databricks AI/BI Dashboard
- **Data source:** Gold tables only, in `hospital_catalog.data`
- **Refresh:** the dashboard is refreshed automatically by the `Hospital_Dashboard` task in `Hospital_billing_Job`, after the pipeline finishes
- **Warehouse:** Serverless Starter Warehouse

## Pages

### 1. Overview
- **KPI cards:** Total Revenue (3.02M), Visits (330), Insurance Covered (1.34M), Pending Amount (658.36K)
- **Revenue by Month:** line chart of monthly revenue across 2025
- **Revenue by Department:** bar chart comparing departments, including rows with an "Unknown" department

Datasets: `gold_monthly_revenue`, `gold_department_summary`, `gold_payer_summary`

### 2. Branch & Payer
- Revenue by branch and region
- Revenue vs insurance amount by payer type
- Payer summary table

Datasets: `gold_branch_summary`, `gold_payer_summary`

### 3. Data Quality
- Cards: Bronze rows, clean rows, rejected rows, duplicate rows
- Reconciliation passed (Yes/No)
- Bar chart of problem counts (duplicates, invalid quantity, negative price, missing department, missing payer, missing amount)

Dataset: `gold_data_quality`

## Data Validation

The dashboard numbers match the Gold tables:
- Total Revenue equals the sum of `total_revenue` in `gold_monthly_revenue`
- Visits (330) matches the number of distinct visits in the dataset
- Reconciliation: 1,010 Bronze rows = 968 clean + 22 rejected + 20 duplicates

## How to Use

1. Run `Hospital_billing_Job` (or upload a new CSV to the volume to trigger it).
2. The pipeline updates the Gold tables, then the dashboard refreshes.
3. Open the published dashboard to see the latest numbers.

## Notes

- All data is synthetic. There is no real patient information.
- Rows with a blank department appear as "Unknown" rather than being removed, so their revenue is still counted.
