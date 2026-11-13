CREATE OR REFRESH STREAMING TABLE bronze_hospital_billing AS
SELECT *,
       _metadata.file_name AS source_file,
       current_timestamp() AS loaded_at
FROM STREAM read_files('/Volumes/hospital_catalog/data/billing_raw_data',
                       format => 'csv', header => true);