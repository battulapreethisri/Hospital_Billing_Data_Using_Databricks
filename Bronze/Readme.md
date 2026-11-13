Bronze Layer: Bronze.sql

The Bronze layer stores the raw hospital billing data exactly as it arrives. A streaming table (bronze_hospital_billing) reads the CSV from the Unity Catalog Volume and adds two audit columns, source_file and loaded_at. No cleaning is done here, so the original data is always preserved. It loads all 1,010 source rows and reads only new files on later runs.
