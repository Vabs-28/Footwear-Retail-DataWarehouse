# Entity Relationship Diagram — FootwearDW

```mermaid
erDiagram
    DIM_DATE {
        int Date_Id PK
        date Full_Date
        int Day
        int Month
        string Month_Name
        int Quarter
        int Year
        string Weekday_Name
        boolean Is_Weekend
    }

    DIM_BRAND {
        int Brand_Id PK
        string Brand_Name
        string Brand_Origin
    }

    DIM_CATEGORY {
        int Category_Id PK
        string Category_Name
        string Segment
    }

    DIM_PRODUCT {
        int Product_Id PK
        string Product_Name
        int Brand_Id FK
        int Category_Id FK
        string Gender
        string Size
        string Color
        decimal Unit_Cost
        decimal Unit_Price
        date Launch_Date
    }

    DIM_STORE {
        int Store_Id PK
        string Store_Name
        string City
        string State
        string Region
        string Channel
    }

    DIM_CUSTOMER {
        int Customer_Id PK
        string Customer_Name
        string Gender
        string Age_Group
        string City
        string Loyalty_Tier
    }

    FACT_SALES {
        bigint Sale_Id PK
        int Date_Id FK
        int Product_Id FK
        int Store_Id FK
        int Customer_Id FK
        int Quantity_Sold
        decimal Unit_Price
        decimal Discount_Pct
        decimal Total_Amount
    }

    FACT_INVENTORY {
        bigint Inventory_Id PK
        int Date_Id FK
        int Product_Id FK
        int Store_Id FK
        int Opening_Stock
        int Received_Stock
        int Sold_Stock
        int Closing_Stock
    }

    DIM_BRAND ||--o{ DIM_PRODUCT : "has"
    DIM_CATEGORY ||--o{ DIM_PRODUCT : "classifies"
    DIM_DATE ||--o{ FACT_SALES : "on"
    DIM_PRODUCT ||--o{ FACT_SALES : "sold as"
    DIM_STORE ||--o{ FACT_SALES : "sold at"
    DIM_CUSTOMER ||--o{ FACT_SALES : "bought by"
    DIM_DATE ||--o{ FACT_INVENTORY : "on"
    DIM_PRODUCT ||--o{ FACT_INVENTORY : "stock of"
    DIM_STORE ||--o{ FACT_INVENTORY : "held at"
```

**Design**: classic star schema — two fact tables (`Fact_Sales`, `Fact_Inventory`)
surrounded by shared conformed dimensions (`Dim_Date`, `Dim_Product`, `Dim_Store`).
`Dim_Product` is itself snowflaked one level into `Dim_Brand` and `Dim_Category`
to avoid repeating brand/category attributes across 120+ product rows.
