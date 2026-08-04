import sqlite3
import pandas as pd

con = sqlite3.connect(":memory:")

tables = ["dim_date", "dim_brand", "dim_category", "dim_product",
          "dim_store", "dim_customer", "fact_sales", "fact_inventory"]

for t in tables:
    df = pd.read_csv(f"../data/{t}.csv")
    df.to_sql(t, con, index=False)
    print(f"loaded {t}: {len(df)} rows")

# quick referential integrity checks
checks = [
    ("orphan sales->product", "SELECT COUNT(*) FROM fact_sales fs LEFT JOIN dim_product dp ON fs.Product_Id=dp.Product_Id WHERE dp.Product_Id IS NULL"),
    ("orphan sales->store", "SELECT COUNT(*) FROM fact_sales fs LEFT JOIN dim_store ds ON fs.Store_Id=ds.Store_Id WHERE ds.Store_Id IS NULL"),
    ("negative totals", "SELECT COUNT(*) FROM fact_sales WHERE Total_Amount < 0"),
    ("zero/negative qty", "SELECT COUNT(*) FROM fact_sales WHERE Quantity_Sold <= 0"),
]
for label, q in checks:
    print(label, "->", con.execute(q).fetchone()[0])

print("\n--- Sample: Total sales by brand ---")
q1 = """
SELECT db.Brand_Name,
       SUM(fs.Total_Amount) AS Total_Sales,
       SUM(fs.Quantity_Sold) AS Units_Sold
FROM fact_sales fs
JOIN dim_product dp ON fs.Product_Id = dp.Product_Id
JOIN dim_brand db ON dp.Brand_Id = db.Brand_Id
GROUP BY db.Brand_Name
ORDER BY Total_Sales DESC
LIMIT 5;
"""
print(pd.read_sql(q1, con))

print("\n--- Sample: Sales by region & channel ---")
q2 = """
SELECT ds.Region, ds.Channel, SUM(fs.Total_Amount) AS Total_Sales
FROM fact_sales fs
JOIN dim_store ds ON fs.Store_Id = ds.Store_Id
GROUP BY ds.Region, ds.Channel
ORDER BY Total_Sales DESC
LIMIT 5;
"""
print(pd.read_sql(q2, con))

print("\n--- Sample: Monthly sales trend ---")
q3 = """
SELECT dd.Year, dd.Month, SUM(fs.Total_Amount) AS Total_Sales
FROM fact_sales fs
JOIN dim_date dd ON fs.Date_Id = dd.Date_Id
GROUP BY dd.Year, dd.Month
ORDER BY dd.Year, dd.Month
LIMIT 6;
"""
print(pd.read_sql(q3, con))

print("\n--- Sample: Inventory turnover ---")
q4 = """
SELECT dp.Product_Name, SUM(fi.Sold_Stock) AS Total_Sold,
       AVG((fi.Opening_Stock + fi.Closing_Stock)/2.0) AS Avg_Inventory
FROM fact_inventory fi
JOIN dim_product dp ON fi.Product_Id = dp.Product_Id
GROUP BY dp.Product_Name
HAVING AVG((fi.Opening_Stock + fi.Closing_Stock)/2.0) > 0
ORDER BY Total_Sold DESC
LIMIT 5;
"""
print(pd.read_sql(q4, con))

print("\nAll validation checks completed.")
