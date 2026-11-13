# Hospital_Billing_Data_Using_Databricks

# Hospital Billing Analytics Platform

A Databricks project that turns a messy hospital billing CSV into clean, trusted summary tables and a dashboard. It uses **Lakeflow Spark Declarative Pipelines (SQL)** and the **Medallion Architecture** (Bronze → Silver → Gold).

## Project Overview

A hospital chain exports patient billing data to a CSV file. The file has extra spaces, inconsistent capitalisation, blank values, duplicate rows, and impossible quantities and prices. This pipeline keeps the raw file, cleans it step by step, builds business-ready tables, and shows them in a dashboard that refreshes automatically when new files arrive.

- **Source:** `hospital_billing_raw.csv` (synthetic data: 1,010 rows, 20 columns, 330 visits in 2025)
- **Platform:** Databricks (Unity Catalog, Lakeflow Pipelines, Jobs, AI/BI Dashboards)
- **Language:** SQL

## Architecture

```
CSV in Unity Catalog Volume
        │
        ▼
   BRONZE  bronze_hospital_billing          (raw + file name + load time)
        │
        ├──────────────► SILVER  silver_billing_clean      (cleaned, deduplicated)
        └──────────────► SILVER  silver_billing_rejected   (bad rows + reason)
                                │
                                ▼
                         GOLD  gold_monthly_revenue
                               gold_department_summary
                               gold_branch_summary
                               gold_payer_summary
                               gold_data_quality
                                │
                                ▼
                        AI/BI Dashboard (3 pages)
```

## Storage Setup

| Item | Value |
|---|---|
| Catalog | `hospital_catalog` |
| Schema | `data` |
| Volume | `billing_raw_data` |
| Pipeline | `Hospital_Pipeline` (one pipeline containing `Bronze.sql`, `Silver.sql`, `Gold.sql`) |
| Job | `Hospital_billing_Job` |

The CSV was uploaded to the volume at `/Volumes/hospital_catalog/data/billing_raw_data/`.

---

## Layer 1: Bronze (raw data)

**Purpose:** keep the source data exactly as it arrived, so the original is never lost and any later step can be re-run.

**What I did**
- Created a Unity Catalog catalog, schema and volume, and uploaded the CSV into the volume.
- Created the streaming table `bronze_hospital_billing`, which reads the CSV from the volume with `read_files` (CSV format, header enabled).
- Added two audit columns: `source_file` (the name of the file each row came from) and `loaded_at` (the load timestamp).
- Made no changes to the source values. Spaces, mixed case, blanks and duplicates are all kept as they were.

**Why a streaming table:** it reads only new files on each run, so new CSVs added to the volume are appended without reprocessing old ones.

**Result:** 1,010 rows loaded, matching the source file.

---

## Layer 2: Silver (cleaned data)

**Purpose:** produce a trustworthy, analysis-ready table and keep every excluded row in a separate table with a reason.

### Tables
- `silver_billing_clean`: rows that pass all checks.
- `silver_billing_rejected`: rows with a bad quantity or price, plus a `reject_reason` column.

### Cleaning rules

| Problem | Rule applied | Why |
|---|---|---|
| Duplicate rows (same `bill_id` repeated) | `SELECT DISTINCT` to keep one copy | Duplicates inflate revenue |
| Extra spaces and mixed case (e.g. `" cardiology"`, `"PRIVATE INSURANCE"`) | `INITCAP(TRIM(column))` | Trim first so leading spaces don't affect capitalisation; Title Case makes groups match in reports |
| Blank department or payer type | Replaced with `'Unknown'` | Keeps the row and its revenue, and shows the gap visibly in reports |
| Blank `total_amount` | `COALESCE(total_amount, quantity * unit_price)` | The amount is defined as quantity × unit price, so it can be calculated safely |
| Blank `patient_id` | Row kept, no change | The revenue is still valid |
| Quantity zero or negative | Dropped from clean table, saved in rejected table | Impossible value |
| Negative unit price | Dropped from clean table, saved in rejected table | Impossible value |

### Data-quality expectations
Two expectations on `silver_billing_clean`, each with `ON VIOLATION DROP ROW`:
- `valid_quantity`: `quantity > 0`
- `valid_unit_price`: `unit_price >= 0`

Dropped rows are counted in the pipeline's data-quality tab.

**Result:** 968 clean rows and 22 rejected rows (each with a reason).

---

## Layer 3: Gold (business tables)

**Purpose:** answer the business questions using the clean rows only.

| Table | Grouped by | Measures | Requirement |
|---|---|---|---|
| `gold_monthly_revenue` | Month of `visit_date` | visits, total revenue, insurance amount | BR-01 |
| `gold_department_summary` | `department` | visits, bills, total revenue, average revenue per visit | BR-02 |
| `gold_branch_summary` | region, city, branch | visits, total revenue | BR-03 |
| `gold_payer_summary` | `payer_type` | visits, total revenue, insurance amount, pending amount | BR-04 |
| `gold_data_quality` | none (one summary row) | bronze, clean and rejected rows, duplicates, count of each problem, reconciliation result | BR-05, BR-06 |

Visits are counted with `COUNT(DISTINCT visit_id)`, because one visit can have several bill lines. Pending amount is a `SUM` with `CASE WHEN payment_status = 'Pending'`.

### Reconciliation check (BR-06)
`gold_data_quality` proves that no row was lost:

```
Bronze rows (1,010) = Clean rows (968) + Rejected rows (22) + Duplicates removed (20)
```

`reconciliation_passed = Yes`.

---

## Dashboard 

Built in **Databricks AI/BI** on the Gold tables only, with three pages:

1. **Overview:** KPI cards (Total Revenue, Visits, Insurance Covered, Pending Amount), monthly revenue line chart, revenue by department.
2. **Branch & Payer:** revenue by branch and region, revenue vs insurance by payer, payer table.
3. **Data Quality:** Bronze, clean, rejected and duplicate row counts, reconciliation passed (Yes/No), chart of problem counts.

The dashboard is published and shared.
https://dbc-31aeaeeb-dd48.cloud.databricks.com/dashboardsv3/01f1df2cc5bc127aad00e4536c124057/published?o=7474657665879443
---

## Repeatability

Everything runs as one Databricks Job, `Hospital_billing_Job`, which can be re-run with one click.

| Task | Type | Depends on |
|---|---|---|
| `Hospital_Data` | Pipeline (`Hospital_Pipeline`: Bronze, Silver, Gold) | none |
| `Hospital_Dashboard` | Dashboard refresh (serverless SQL warehouse) | `Hospital_Data` |

- **One click:** *Run now* runs the pipeline, then refreshes the published dashboard.
- **Automatic runs:** a **File arrival** trigger watches `/Volumes/hospital_catalog/data/billing_raw_data/`. When a new CSV is added, the job starts, Bronze reads only the new file, Silver and Gold update, and the dashboard refreshes.
- **Same result on re-run:** running the job again on the same data gives the same Gold numbers, and the reconciliation check still passes.

---

## How to Run This Project

1. Create the catalog, schema and volume:
   ```sql
   CREATE CATALOG IF NOT EXISTS hospital_catalog;
   CREATE SCHEMA  IF NOT EXISTS hospital_catalog.data;
   CREATE VOLUME  IF NOT EXISTS hospital_catalog.data.billing_raw_data;
   ```
2. Upload `hospital_billing_raw.csv` to the volume (Catalog → `hospital_catalog` → `data` → `billing_raw_data` → Upload).
3. Create an ETL pipeline with default catalog `hospital_catalog` and default schema `data`, and add `Bronze.sql`, `Silver.sql` and `Gold.sql` as its source files.
4. Run the pipeline once (Full refresh).
5. Check the result:
   ```sql
   SELECT * FROM hospital_catalog.data.gold_data_quality;
   ```
6. Create a job with two tasks: the pipeline, then the dashboard refresh (depends on the pipeline task). Optionally add a File arrival trigger on the volume path.
7. Build or import the dashboard on the `gold_*` tables and publish it.

**Adding new data:** upload a new CSV with the same 20 columns and header, using a **new file name**, to the volume. With the File arrival trigger on, the job runs by itself.

## Screenshots
- Pipeline graph (all layers connected)
<img width="1092" height="587" alt="image" src="https://github.com/user-attachments/assets/fa526679-2767-4313-9bad-4eebfab0f9fa" />


- Job graph with both tasks green and the Runs list
  <img width="1913" height="900" alt="image" src="https://github.com/user-attachments/assets/3f778d34-6785-46f4-824a-325e9faf11a1" />
  <img width="1663" height="805" alt="image" src="https://github.com/user-attachments/assets/d1e6b78c-2356-4bc0-a686-35d38a26ac1c" />


## Key Takeaway

Each layer makes the data more trustworthy: **Bronze** keeps it, **Silver** cleans it, **Gold** summarises it, and the **dashboard** shares it.
