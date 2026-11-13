CREATE OR REFRESH MATERIALIZED VIEW silver_billing_clean (
  CONSTRAINT valid_quantity   EXPECT (quantity > 0)     ON VIOLATION DROP ROW,
  CONSTRAINT valid_unit_price EXPECT (unit_price >= 0)  ON VIOLATION DROP ROW
) AS
SELECT DISTINCT
  TRIM(bill_id)                                              AS bill_id,
  TRIM(visit_id)                                             AS visit_id,
  NULLIF(TRIM(patient_id), '')                               AS patient_id,   -- blank stays blank
  INITCAP(TRIM(patient_gender))                              AS patient_gender,
  TRY_CAST(patient_age AS INT)                               AS patient_age,
  TRY_CAST(visit_date AS DATE)                               AS visit_date,
  INITCAP(TRIM(visit_type))                                  AS visit_type,
  COALESCE(NULLIF(INITCAP(TRIM(department)), ''), 'Unknown') AS department,
  TRIM(doctor_name)                                          AS doctor_name,
  INITCAP(TRIM(service_category))                            AS service_category,
  INITCAP(TRIM(service_name))                                AS service_name,
  TRIM(hospital_branch)                                      AS hospital_branch,  -- code, so no INITCAP
  INITCAP(TRIM(city))                                        AS city,
  INITCAP(TRIM(region))                                      AS region,
  COALESCE(NULLIF(INITCAP(TRIM(payer_type)), ''), 'Unknown') AS payer_type,
  TRY_CAST(quantity AS INT)                                  AS quantity,
  TRY_CAST(unit_price AS DECIMAL(12,2))                      AS unit_price,
  COALESCE(TRY_CAST(total_amount AS DECIMAL(12,2)),
           TRY_CAST(quantity AS INT) * TRY_CAST(unit_price AS DECIMAL(12,2))) AS total_amount,
  TRY_CAST(insurance_amount AS DECIMAL(12,2))                AS insurance_amount,
  INITCAP(TRIM(payment_status))                              AS payment_status
FROM bronze_hospital_billing;

CREATE OR REFRESH MATERIALIZED VIEW silver_billing_rejected AS
SELECT DISTINCT * EXCEPT (source_file, loaded_at),
  CASE WHEN quantity <= 0 THEN 'Quantity is zero or negative'
       ELSE 'Unit price is negative' END AS reject_reason
FROM bronze_hospital_billing
WHERE quantity <= 0 OR unit_price < 0;