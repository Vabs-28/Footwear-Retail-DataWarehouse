-- ============================================================
-- FootwearDW: Business Analytics Queries
-- Mirrors the kind of sales/category/geography/channel reporting
-- a BA role in a footwear brand would be expected to produce.
-- ============================================================

-- 1) Total sales & units by brand
SELECT db.Brand_Name,
       SUM(fs.Total_Amount) AS Total_Sales,
       SUM(fs.Quantity_Sold) AS Units_Sold
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Id = dp.Product_Id
JOIN Dim_Brand db ON dp.Brand_Id = db.Brand_Id
GROUP BY db.Brand_Name
ORDER BY Total_Sales DESC;

-- 2) Total sales by category & segment
SELECT dc.Category_Name, dc.Segment,
       SUM(fs.Total_Amount) AS Total_Sales
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Id = dp.Product_Id
JOIN Dim_Category dc ON dp.Category_Id = dc.Category_Id
GROUP BY dc.Category_Name, dc.Segment
ORDER BY Total_Sales DESC;

-- 3) Sales by region & channel (geography x channel matrix)
SELECT ds.Region, ds.Channel,
       SUM(fs.Total_Amount) AS Total_Sales,
       COUNT(*) AS Transactions
FROM Fact_Sales fs
JOIN Dim_Store ds ON fs.Store_Id = ds.Store_Id
GROUP BY ds.Region, ds.Channel
ORDER BY ds.Region, Total_Sales DESC;

-- 4) Monthly sales trend
SELECT dd.Year, dd.Month, dd.Month_Name,
       SUM(fs.Total_Amount) AS Total_Sales
FROM Fact_Sales fs
JOIN Dim_Date dd ON fs.Date_Id = dd.Date_Id
GROUP BY dd.Year, dd.Month, dd.Month_Name
ORDER BY dd.Year, dd.Month;

-- 5) Top 10 best-selling products
SELECT dp.Product_Name, db.Brand_Name,
       SUM(fs.Quantity_Sold) AS Units_Sold,
       SUM(fs.Total_Amount) AS Total_Sales
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Id = dp.Product_Id
JOIN Dim_Brand db ON dp.Brand_Id = db.Brand_Id
GROUP BY dp.Product_Name, db.Brand_Name
ORDER BY Units_Sold DESC
LIMIT 10;

-- 6) Sales by size & gender (footwear-specific demand pattern)
SELECT dp.Gender, dp.Size,
       SUM(fs.Quantity_Sold) AS Units_Sold
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Id = dp.Product_Id
GROUP BY dp.Gender, dp.Size
ORDER BY dp.Gender, Units_Sold DESC;

-- 7) Store performance ranking (within region)
SELECT ds.Region, ds.Store_Name,
       SUM(fs.Total_Amount) AS Total_Sales,
       RANK() OVER (PARTITION BY ds.Region ORDER BY SUM(fs.Total_Amount) DESC) AS Region_Rank
FROM Fact_Sales fs
JOIN Dim_Store ds ON fs.Store_Id = ds.Store_Id
GROUP BY ds.Region, ds.Store_Name
ORDER BY ds.Region, Region_Rank;

-- 8) Discount impact: sales volume & revenue by discount band
SELECT fs.Discount_Pct,
       COUNT(*) AS Transactions,
       SUM(fs.Quantity_Sold) AS Units_Sold,
       SUM(fs.Total_Amount) AS Total_Sales
FROM Fact_Sales fs
GROUP BY fs.Discount_Pct
ORDER BY fs.Discount_Pct;

-- 9) Customer loyalty tier contribution to revenue
SELECT dcu.Loyalty_Tier,
       COUNT(DISTINCT dcu.Customer_Id) AS Customers,
       SUM(fs.Total_Amount) AS Total_Sales
FROM Fact_Sales fs
JOIN Dim_Customer dcu ON fs.Customer_Id = dcu.Customer_Id
GROUP BY dcu.Loyalty_Tier
ORDER BY Total_Sales DESC;

-- 10) Inventory turnover ratio by product (Units Sold / Avg Inventory)
SELECT dp.Product_Name,
       SUM(fi.Sold_Stock) AS Total_Sold,
       ROUND(AVG((fi.Opening_Stock + fi.Closing_Stock) / 2.0), 1) AS Avg_Inventory,
       ROUND(SUM(fi.Sold_Stock) / NULLIF(AVG((fi.Opening_Stock + fi.Closing_Stock) / 2.0), 0), 2) AS Turnover_Ratio
FROM Fact_Inventory fi
JOIN Dim_Product dp ON fi.Product_Id = dp.Product_Id
GROUP BY dp.Product_Name
ORDER BY Turnover_Ratio DESC
LIMIT 10;

-- 11) Products at risk of stockout (latest snapshot, low closing stock)
SELECT dp.Product_Name, ds.Store_Name, fi.Closing_Stock, dd.Full_Date
FROM Fact_Inventory fi
JOIN Dim_Product dp ON fi.Product_Id = dp.Product_Id
JOIN Dim_Store ds ON fi.Store_Id = ds.Store_Id
JOIN Dim_Date dd ON fi.Date_Id = dd.Date_Id
WHERE fi.Closing_Stock <= 5
ORDER BY dd.Full_Date DESC, fi.Closing_Stock ASC
LIMIT 20;

-- 12) Quarter-over-quarter sales growth
WITH quarterly AS (
    SELECT dd.Year, dd.Quarter, SUM(fs.Total_Amount) AS Total_Sales
    FROM Fact_Sales fs
    JOIN Dim_Date dd ON fs.Date_Id = dd.Date_Id
    GROUP BY dd.Year, dd.Quarter
)
SELECT Year, Quarter, Total_Sales,
       LAG(Total_Sales) OVER (ORDER BY Year, Quarter) AS Prev_Quarter_Sales,
       ROUND(
         100.0 * (Total_Sales - LAG(Total_Sales) OVER (ORDER BY Year, Quarter))
         / NULLIF(LAG(Total_Sales) OVER (ORDER BY Year, Quarter), 0), 2
       ) AS QoQ_Growth_Pct
FROM quarterly
ORDER BY Year, Quarter;
