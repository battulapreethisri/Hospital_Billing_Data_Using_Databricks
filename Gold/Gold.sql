CREATE OR REFRESH MATERIALIZED VIEW gold_monthly_revenue AS
SELECT DATE_TRUNC('MONTH', visit_date) AS visit_month,
       COUNT(DISTINCT visit_id)        AS visits,
       SUM(total_amount)               AS total_revenue,
       SUM(insurance_amount)           AS insurance_amount
FROM silver_billing_clean
GROUP BY DATE_TRUNC('MONTH', visit_date);

CREATE OR REFRESH MATERIALIZED VIEW gold_department_summary AS
SELECT department,
       COUNT(DISTINCT visit_id)                          AS visits,
       COUNT(*)                                          AS bills,
       SUM(total_amount)                                 AS total_revenue,
       SUM(total_amount) / COUNT(DISTINCT visit_id)      AS avg_revenue_per_visit
FROM silver_billing_clean
GROUP BY department;

CREATE OR REFRESH MATERIALIZED VIEW gold_branch_summary AS
SELECT region, city, hospital_branch,
       COUNT(DISTINCT visit_id) AS visits,
       SUM(total_amount)        AS total_revenue
FROM silver_billing_clean
GROUP BY region, city, hospital_branch;

CREATE OR REFRESH MATERIALIZED VIEW gold_payer_summary AS
SELECT payer_type,
       COUNT(DISTINCT visit_id) AS visits,
       SUM(total_amount)        AS total_revenue,
       SUM(insurance_amount)    AS insurance_amount,
       SUM(CASE WHEN payment_status = 'Pending' THEN total_amount ELSE 0 END) AS pending_amount
FROM silver_billing_clean
GROUP BY payer_type;
CREATE OR REFRESH MATERIALIZED VIEW gold_data_quality AS
WITH b AS (
  SELECT COUNT(*)                                                        AS bronze_rows,
         COUNT(*) - COUNT(DISTINCT bill_id)                              AS duplicate_rows,
         SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END)                  AS invalid_quantity_rows,
         SUM(CASE WHEN unit_price < 0 THEN 1 ELSE 0 END)                 AS negative_price_rows,
         SUM(CASE WHEN NULLIF(TRIM(department),'') IS NULL THEN 1 ELSE 0 END) AS missing_department_rows,
         SUM(CASE WHEN NULLIF(TRIM(payer_type),'') IS NULL THEN 1 ELSE 0 END) AS missing_payer_rows,
         SUM(CASE WHEN total_amount IS NULL THEN 1 ELSE 0 END)           AS missing_amount_rows,
         SUM(CASE WHEN NULLIF(TRIM(patient_id),'') IS NULL THEN 1 ELSE 0 END) AS missing_patient_rows
  FROM bronze_hospital_billing
),
c AS (SELECT COUNT(*) AS clean_rows    FROM silver_billing_clean),
r AS (SELECT COUNT(*) AS rejected_rows FROM silver_billing_rejected)
SELECT b.*, c.clean_rows, r.rejected_rows,
       CASE WHEN b.bronze_rows = c.clean_rows + r.rejected_rows + b.duplicate_rows
            THEN 'Yes' ELSE 'No' END AS reconciliation_passed
FROM b CROSS JOIN c CROSS JOIN r;