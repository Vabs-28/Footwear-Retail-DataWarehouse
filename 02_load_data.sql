-- ============================================================
-- FootwearDW: Load synthetic CSV data (PostgreSQL)
-- Run 01_schema.sql first. Update the path below to where you
-- cloned the repo (or place the CSVs alongside psql).
-- ============================================================

\set data_dir 'data'

COPY Dim_Date FROM :'data_dir/dim_date.csv' DELIMITER ',' CSV HEADER;
COPY Dim_Brand FROM :'data_dir/dim_brand.csv' DELIMITER ',' CSV HEADER;
COPY Dim_Category FROM :'data_dir/dim_category.csv' DELIMITER ',' CSV HEADER;
COPY Dim_Product FROM :'data_dir/dim_product.csv' DELIMITER ',' CSV HEADER;
COPY Dim_Store FROM :'data_dir/dim_store.csv' DELIMITER ',' CSV HEADER;
COPY Dim_Customer FROM :'data_dir/dim_customer.csv' DELIMITER ',' CSV HEADER;

-- Fact_Sales.Customer_Id can be blank (guest checkout / walk-in sale);
-- treat empty strings as NULL on load.
COPY Fact_Sales FROM :'data_dir/fact_sales.csv' DELIMITER ',' CSV HEADER NULL AS '';
COPY Fact_Inventory FROM :'data_dir/fact_inventory.csv' DELIMITER ',' CSV HEADER;

-- Sanity checks after load
SELECT 'Dim_Date' AS table_name, COUNT(*) FROM Dim_Date
UNION ALL SELECT 'Dim_Brand', COUNT(*) FROM Dim_Brand
UNION ALL SELECT 'Dim_Category', COUNT(*) FROM Dim_Category
UNION ALL SELECT 'Dim_Product', COUNT(*) FROM Dim_Product
UNION ALL SELECT 'Dim_Store', COUNT(*) FROM Dim_Store
UNION ALL SELECT 'Dim_Customer', COUNT(*) FROM Dim_Customer
UNION ALL SELECT 'Fact_Sales', COUNT(*) FROM Fact_Sales
UNION ALL SELECT 'Fact_Inventory', COUNT(*) FROM Fact_Inventory;
