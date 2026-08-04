# 👟 FootwearDW — Footwear Retail Data Warehouse

Design and implementation of a **PostgreSQL data warehouse** for a footwear
brand, built on a star schema to support sales, inventory, and channel/
geography reporting. This extends the simpler OLTP-style
[Retail Inventory & Sales Management Database](https://github.com/Vabs-28/Retail-Inventory-And-Sales-Management-Database)
project from a single normalized schema into a proper dimensional model
sized for analytics — the kind of structure a BI/BA team would query for
category, region, and channel performance.

---

## 🔹 Features

- 🏗️ Star schema: 2 fact tables + 6 dimensions
- 📦 Sales and inventory tracked at daily grain, by product/store/customer
- 🌍 Geography (region/state/city) and channel (online/retail/wholesale/
  franchise) reporting built in
- 🔐 Data integrity via PK/FK constraints and CHECK constraints on every
  numeric/categorical column
- 📊 12 ready-to-run business reports covering sales, inventory, and
  customer analysis
- 🧪 Synthetic dataset (~20K sales rows, ~126K inventory snapshots, 2 years)
  plus a reproducible Python generator
- ✅ Referential-integrity and constraint checks validated before shipping

---

## 🔹 Why a warehouse, not just a transactional DB

The [reference project](https://github.com/Vabs-28/Retail-Inventory-And-Sales-Management-Database)
models a single store's `Categories → Product → Sales` flow — good for
day-to-day operations, but every report has to join the same three tables
over and over, and there's no way to slice by store, region, channel, or
time period without ad-hoc date math.

`FootwearDW` instead separates **facts** (what happened — a sale, a stock
count) from **dimensions** (the context it happened in — which product,
which store, which day). That's what makes "sales by category by region by
month" a single `GROUP BY` instead of a bespoke query every time.

---

## 🔹 Database Schema

### ⭐ Star schema

See [`docs/ERD.md`](docs/ERD.md) for the full entity-relationship diagram.

**Fact tables**
- `Fact_Sales` — one row per line item sold (grain: sale × product)
- `Fact_Inventory` — one row per product per store per day (grain: daily stock snapshot)

**Dimension tables**
- `Dim_Date`, `Dim_Brand`, `Dim_Category`, `Dim_Product`, `Dim_Store`, `Dim_Customer`

```sql
CREATE TABLE Fact_Sales (
    Sale_Id        BIGINT PRIMARY KEY,
    Date_Id        INT NOT NULL REFERENCES Dim_Date(Date_Id),
    Product_Id     INT NOT NULL REFERENCES Dim_Product(Product_Id),
    Store_Id       INT NOT NULL REFERENCES Dim_Store(Store_Id),
    Customer_Id    INT REFERENCES Dim_Customer(Customer_Id),
    Quantity_Sold  INT NOT NULL,
    Unit_Price     DECIMAL(10,2) NOT NULL,
    Discount_Pct   DECIMAL(5,2) NOT NULL DEFAULT 0,
    Total_Amount   DECIMAL(12,2) NOT NULL
);
```

Full DDL: [`sql/01_schema.sql`](sql/01_schema.sql)

---

## 🔹 Data Integrity & Validation

```sql
ALTER TABLE Dim_Product ADD CONSTRAINT chk_price_above_cost CHECK (Unit_Price >= Unit_Cost);
ALTER TABLE Fact_Sales ADD CONSTRAINT chk_qty_positive CHECK (Quantity_Sold > 0);
ALTER TABLE Fact_Sales ADD CONSTRAINT chk_discount_range CHECK (Discount_Pct BETWEEN 0 AND 100);
ALTER TABLE Fact_Inventory ADD CONSTRAINT uq_inventory_grain UNIQUE (Date_Id, Product_Id, Store_Id);
```

✔ Prevents negative/zero quantities and prices
✔ Prevents discounts outside 0–100%
✔ Prevents selling below cost price at the catalog level
✔ Prevents duplicate inventory snapshots for the same product/store/day
✔ Foreign keys prevent orphan fact rows

---

## 🔹 Sample Business Reports

Full set in [`sql/03_analytics_queries.sql`](sql/03_analytics_queries.sql). Examples:

**Total sales by brand**
```sql
SELECT db.Brand_Name, SUM(fs.Total_Amount) AS Total_Sales, SUM(fs.Quantity_Sold) AS Units_Sold
FROM Fact_Sales fs
JOIN Dim_Product dp ON fs.Product_Id = dp.Product_Id
JOIN Dim_Brand db ON dp.Brand_Id = db.Brand_Id
GROUP BY db.Brand_Name
ORDER BY Total_Sales DESC;
```

**Sales by region & channel**
```sql
SELECT ds.Region, ds.Channel, SUM(fs.Total_Amount) AS Total_Sales
FROM Fact_Sales fs
JOIN Dim_Store ds ON fs.Store_Id = ds.Store_Id
GROUP BY ds.Region, ds.Channel
ORDER BY ds.Region, Total_Sales DESC;
```

**Quarter-over-quarter growth** (window function)
```sql
WITH quarterly AS (
    SELECT dd.Year, dd.Quarter, SUM(fs.Total_Amount) AS Total_Sales
    FROM Fact_Sales fs JOIN Dim_Date dd ON fs.Date_Id = dd.Date_Id
    GROUP BY dd.Year, dd.Quarter
)
SELECT Year, Quarter, Total_Sales,
       LAG(Total_Sales) OVER (ORDER BY Year, Quarter) AS Prev_Quarter_Sales
FROM quarterly ORDER BY Year, Quarter;
```

Other reports include: category/segment sales, top-10 products, size &
gender demand mix, store performance ranking within region, discount-band
impact, loyalty-tier revenue contribution, inventory turnover ratio, and a
stockout-risk list.

---

## 🔹 Dataset

`scripts/generate_data.py` produces a reproducible synthetic dataset
(seeded, so re-running gives identical output):

| Table | Rows |
|---|---|
| Dim_Date | 731 (2 full years) |
| Dim_Brand | 10 |
| Dim_Category | 8 |
| Dim_Product | 120 |
| Dim_Store | 25 |
| Dim_Customer | 400 |
| Fact_Sales | 20,000 |
| Fact_Inventory | 126,000 |

CSVs live in `data/`. Load them into Postgres with
[`sql/02_load_data.sql`](sql/02_load_data.sql) after running `01_schema.sql`.

---

## 🔹 Testing

| Test Case | Result |
|---|---|
| Load all CSVs, check referential integrity (sales→product, sales→store) | ✅ 0 orphan rows |
| Insert sale with negative quantity | ❌ Rejected |
| Insert sale with discount > 100% | ❌ Rejected |
| Insert product priced below cost | ❌ Rejected |
| Duplicate inventory snapshot (same date/product/store) | ❌ Rejected |
| Run all 12 analytics queries end-to-end | ✅ All return expected shape |

Validated with `scripts/validate.py` (loads CSVs into SQLite as a fast
local check before touching Postgres).

---

## 🔹 Tools Used

- PostgreSQL (schema, constraints, analytics queries)
- Python (Faker, pandas) for reproducible synthetic data generation
- Mermaid for the ERD

---

## 🔹 Project Structure

```
footwear-dw/
├── README.md
├── docs/
│   └── ERD.md
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_data.sql
│   └── 03_analytics_queries.sql
├── scripts/
│   ├── generate_data.py
│   └── validate.py
└── data/
    ├── dim_date.csv
    ├── dim_brand.csv
    ├── dim_category.csv
    ├── dim_product.csv
    ├── dim_store.csv
    ├── dim_customer.csv
    ├── fact_sales.csv
    └── fact_inventory.csv
```

---

## ✅ Conclusion

`FootwearDW` provides a **dimensional data warehouse** for a footwear
retail business that:
✔ Separates facts from context for flexible slicing (product/store/time/customer)
✔ Enforces strong data integrity across every table
✔ Answers sales, inventory, and customer questions by category, geography,
   and channel in a single query
✔ Ships with a reproducible synthetic dataset and validated query set
