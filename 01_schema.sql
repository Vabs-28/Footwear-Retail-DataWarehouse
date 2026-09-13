-- ============================================================
-- FootwearDW: Retail Footwear Data Warehouse
-- Star Schema DDL (PostgreSQL)
-- ============================================================

-- ================= DIMENSION TABLES =================

-- Date dimension
CREATE TABLE Dim_Date (
    Date_Id       INT PRIMARY KEY,
    Full_Date     DATE NOT NULL UNIQUE,
    Day           INT NOT NULL,
    Month         INT NOT NULL,
    Month_Name    VARCHAR(15) NOT NULL,
    Quarter       INT NOT NULL,
    Year          INT NOT NULL,
    Weekday_Name  VARCHAR(15) NOT NULL,
    Is_Weekend    BOOLEAN NOT NULL,
    CONSTRAINT chk_month CHECK (Month BETWEEN 1 AND 12),
    CONSTRAINT chk_quarter CHECK (Quarter BETWEEN 1 AND 4)
);

-- Brand dimension
CREATE TABLE Dim_Brand (
    Brand_Id      INT PRIMARY KEY,
    Brand_Name    VARCHAR(50) NOT NULL UNIQUE,
    Brand_Origin  VARCHAR(50)
);

-- Category dimension
CREATE TABLE Dim_Category (
    Category_Id    INT PRIMARY KEY,
    Category_Name  VARCHAR(50) NOT NULL,
    Segment        VARCHAR(30) NOT NULL,
    CONSTRAINT chk_segment CHECK (Segment IN ('Casual','Sports','Formal','Outdoor','Sandals & Slippers'))
);

-- Product dimension
CREATE TABLE Dim_Product (
    Product_Id    INT PRIMARY KEY,
    Product_Name  VARCHAR(100) NOT NULL,
    Brand_Id      INT NOT NULL REFERENCES Dim_Brand(Brand_Id),
    Category_Id   INT NOT NULL REFERENCES Dim_Category(Category_Id),
    Gender        VARCHAR(10) NOT NULL,
    Size          VARCHAR(5) NOT NULL,
    Color         VARCHAR(20),
    Unit_Cost     DECIMAL(10,2) NOT NULL,
    Unit_Price    DECIMAL(10,2) NOT NULL,
    Launch_Date   DATE,
    CONSTRAINT chk_gender CHECK (Gender IN ('Men','Women','Kids','Unisex')),
    CONSTRAINT chk_unit_cost_positive CHECK (Unit_Cost > 0),
    CONSTRAINT chk_unit_price_positive CHECK (Unit_Price > 0),
    CONSTRAINT chk_price_above_cost CHECK (Unit_Price >= Unit_Cost)
);

-- Store / channel dimension
CREATE TABLE Dim_Store (
    Store_Id      INT PRIMARY KEY,
    Store_Name    VARCHAR(100) NOT NULL,
    City          VARCHAR(50) NOT NULL,
    State         VARCHAR(50) NOT NULL,
    Region        VARCHAR(20) NOT NULL,
    Channel       VARCHAR(20) NOT NULL,
    CONSTRAINT chk_region CHECK (Region IN ('North','South','East','West','Central')),
    CONSTRAINT chk_channel CHECK (Channel IN ('Online','Retail Store','Wholesale','Franchise'))
);

-- Customer dimension
CREATE TABLE Dim_Customer (
    Customer_Id    INT PRIMARY KEY,
    Customer_Name  VARCHAR(100) NOT NULL,
    Gender         VARCHAR(10),
    Age_Group      VARCHAR(10) NOT NULL,
    City           VARCHAR(50),
    Loyalty_Tier   VARCHAR(10) NOT NULL DEFAULT 'None',
    CONSTRAINT chk_age_group CHECK (Age_Group IN ('<18','18-24','25-34','35-44','45-54','55+')),
    CONSTRAINT chk_loyalty_tier CHECK (Loyalty_Tier IN ('None','Silver','Gold','Platinum'))
);

-- ================= FACT TABLES =================

-- Sales fact (grain: one row per line item sold)
CREATE TABLE Fact_Sales (
    Sale_Id        BIGINT PRIMARY KEY,
    Date_Id        INT NOT NULL REFERENCES Dim_Date(Date_Id),
    Product_Id     INT NOT NULL REFERENCES Dim_Product(Product_Id),
    Store_Id       INT NOT NULL REFERENCES Dim_Store(Store_Id),
    Customer_Id    INT REFERENCES Dim_Customer(Customer_Id),
    Quantity_Sold  INT NOT NULL,
    Unit_Price     DECIMAL(10,2) NOT NULL,
    Discount_Pct   DECIMAL(5,2) NOT NULL DEFAULT 0,
    Total_Amount   DECIMAL(12,2) NOT NULL,
    CONSTRAINT chk_qty_positive CHECK (Quantity_Sold > 0),
    CONSTRAINT chk_sales_unit_price_positive CHECK (Unit_Price > 0),
    CONSTRAINT chk_discount_range CHECK (Discount_Pct >= 0 AND Discount_Pct <= 100),
    CONSTRAINT chk_total_non_negative CHECK (Total_Amount >= 0)
);

-- Inventory fact (grain: one row per product, per store, per day)
CREATE TABLE Fact_Inventory (
    Inventory_Id     BIGINT PRIMARY KEY,
    Date_Id          INT NOT NULL REFERENCES Dim_Date(Date_Id),
    Product_Id       INT NOT NULL REFERENCES Dim_Product(Product_Id),
    Store_Id         INT NOT NULL REFERENCES Dim_Store(Store_Id),
    Opening_Stock    INT NOT NULL,
    Received_Stock   INT NOT NULL,
    Sold_Stock       INT NOT NULL,
    Closing_Stock    INT NOT NULL,
    CONSTRAINT chk_opening_non_negative CHECK (Opening_Stock >= 0),
    CONSTRAINT chk_received_non_negative CHECK (Received_Stock >= 0),
    CONSTRAINT chk_sold_non_negative CHECK (Sold_Stock >= 0),
    CONSTRAINT chk_closing_non_negative CHECK (Closing_Stock >= 0),
    CONSTRAINT uq_inventory_grain UNIQUE (Date_Id, Product_Id, Store_Id)
);

-- ================= INDEXES FOR ANALYTICS =================
CREATE INDEX idx_sales_date ON Fact_Sales(Date_Id);
CREATE INDEX idx_sales_product ON Fact_Sales(Product_Id);
CREATE INDEX idx_sales_store ON Fact_Sales(Store_Id);
CREATE INDEX idx_inventory_date ON Fact_Inventory(Date_Id);
CREATE INDEX idx_inventory_product ON Fact_Inventory(Product_Id);
CREATE INDEX idx_product_brand ON Dim_Product(Brand_Id);
CREATE INDEX idx_product_category ON Dim_Product(Category_Id);
