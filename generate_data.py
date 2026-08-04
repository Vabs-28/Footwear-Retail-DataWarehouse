"""
FootwearDW synthetic data generator.

Generates dimension and fact CSVs for the footwear retail data warehouse.
Output lands in ../data/ as CSVs, ready to load into Postgres via COPY
(see sql/03_load_data.sql) or into any other RDBMS.
"""

import csv
import random
from datetime import date, timedelta

from faker import Faker

fake = Faker("en_IN")
random.seed(42)
Faker.seed(42)

OUT_DIR = "../data"

# ---------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------
BRANDS = [
    ("Campus", "India"),
    ("Sparx", "India"),
    ("Bata", "India"),
    ("Adidas", "Germany"),
    ("Nike", "USA"),
    ("Puma", "Germany"),
    ("Woodland", "India"),
    ("Skechers", "USA"),
    ("Red Chief", "India"),
    ("Liberty", "India"),
]

CATEGORIES = [
    ("Running Shoes", "Sports"),
    ("Sneakers", "Casual"),
    ("Formal Shoes", "Formal"),
    ("Sandals", "Sandals & Slippers"),
    ("Flip Flops", "Sandals & Slippers"),
    ("Boots", "Outdoor"),
    ("Sports Sandals", "Sports"),
    ("Loafers", "Formal"),
]

GENDERS = ["Men", "Women", "Kids", "Unisex"]
SIZES = ["4", "5", "6", "7", "8", "9", "10", "11"]
COLORS = ["Black", "White", "Grey", "Navy", "Red", "Tan", "Blue", "Olive"]

REGIONS = ["North", "South", "East", "West", "Central"]
CHANNELS = ["Online", "Retail Store", "Wholesale", "Franchise"]

CITY_STATE_REGION = [
    ("Delhi", "Delhi", "North"),
    ("Jaipur", "Rajasthan", "North"),
    ("Chandigarh", "Punjab", "North"),
    ("Mumbai", "Maharashtra", "West"),
    ("Pune", "Maharashtra", "West"),
    ("Ahmedabad", "Gujarat", "West"),
    ("Bengaluru", "Karnataka", "South"),
    ("Chennai", "Tamil Nadu", "South"),
    ("Hyderabad", "Telangana", "South"),
    ("Kolkata", "West Bengal", "East"),
    ("Patna", "Bihar", "East"),
    ("Bhopal", "Madhya Pradesh", "Central"),
    ("Nagpur", "Maharashtra", "Central"),
]

AGE_GROUPS = ["<18", "18-24", "25-34", "35-44", "45-54", "55+"]
LOYALTY_TIERS = ["None", "Silver", "Gold", "Platinum"]

N_PRODUCTS = 120
N_STORES = 25
N_CUSTOMERS = 400
START_DATE = date(2024, 1, 1)
END_DATE = date(2025, 12, 31)
N_SALES_ROWS = 20000


def write_csv(filename, header, rows):
    path = f"{OUT_DIR}/{filename}"
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"wrote {len(rows)} rows -> {path}")


def build_dim_date():
    rows = []
    d = START_DATE
    date_id_map = {}
    idx = 1
    while d <= END_DATE:
        date_id = int(d.strftime("%Y%m%d"))
        date_id_map[d] = date_id
        rows.append([
            date_id, d.isoformat(), d.day, d.month, d.strftime("%B"),
            (d.month - 1) // 3 + 1, d.year, d.strftime("%A"),
            d.weekday() >= 5,
        ])
        d += timedelta(days=1)
        idx += 1
    write_csv("dim_date.csv",
               ["Date_Id", "Full_Date", "Day", "Month", "Month_Name",
                "Quarter", "Year", "Weekday_Name", "Is_Weekend"], rows)
    return date_id_map


def build_dim_brand():
    rows = [[i + 1, name, origin] for i, (name, origin) in enumerate(BRANDS)]
    write_csv("dim_brand.csv", ["Brand_Id", "Brand_Name", "Brand_Origin"], rows)
    return [r[0] for r in rows]


def build_dim_category():
    rows = [[i + 1, name, seg] for i, (name, seg) in enumerate(CATEGORIES)]
    write_csv("dim_category.csv", ["Category_Id", "Category_Name", "Segment"], rows)
    return [r[0] for r in rows]


def build_dim_product(brand_ids, category_ids):
    rows = []
    for pid in range(1, N_PRODUCTS + 1):
        brand_id = random.choice(brand_ids)
        category_id = random.choice(category_ids)
        gender = random.choice(GENDERS)
        size = random.choice(SIZES)
        color = random.choice(COLORS)
        unit_cost = round(random.uniform(300, 3500), 2)
        margin = random.uniform(1.25, 2.2)
        unit_price = round(unit_cost * margin, 2)
        launch_date = fake.date_between(start_date=date(2022, 1, 1), end_date=date(2025, 6, 1))
        cat_name = CATEGORIES[category_id - 1][0]
        brand_name = BRANDS[brand_id - 1][0]
        product_name = f"{brand_name} {cat_name} {color} {gender}"
        rows.append([pid, product_name, brand_id, category_id, gender, size,
                     color, unit_cost, unit_price, launch_date.isoformat()])
    write_csv("dim_product.csv",
              ["Product_Id", "Product_Name", "Brand_Id", "Category_Id", "Gender",
               "Size", "Color", "Unit_Cost", "Unit_Price", "Launch_Date"], rows)
    return rows


def build_dim_store():
    rows = []
    for sid in range(1, N_STORES + 1):
        city, state, region = random.choice(CITY_STATE_REGION)
        channel = random.choice(CHANNELS)
        store_name = f"{city} {channel} #{sid}"
        rows.append([sid, store_name, city, state, region, channel])
    write_csv("dim_store.csv",
              ["Store_Id", "Store_Name", "City", "State", "Region", "Channel"], rows)
    return rows


def build_dim_customer():
    rows = []
    for cid in range(1, N_CUSTOMERS + 1):
        name = fake.name()
        gender = random.choice(["Male", "Female"])
        age_group = random.choice(AGE_GROUPS)
        city = random.choice(CITY_STATE_REGION)[0]
        loyalty = random.choices(LOYALTY_TIERS, weights=[50, 25, 15, 10])[0]
        rows.append([cid, name, gender, age_group, city, loyalty])
    write_csv("dim_customer.csv",
              ["Customer_Id", "Customer_Name", "Gender", "Age_Group", "City", "Loyalty_Tier"], rows)
    return rows


def build_fact_sales(date_id_map, product_rows, store_rows, customer_rows):
    dates = list(date_id_map.items())
    rows = []
    for sale_id in range(1, N_SALES_ROWS + 1):
        d, date_id = random.choice(dates)
        product = random.choice(product_rows)
        store = random.choice(store_rows)
        customer = random.choice(customer_rows) if random.random() > 0.1 else None
        product_id = product[0]
        unit_price = float(product[8])
        qty = random.choices([1, 2, 3, 4], weights=[70, 20, 7, 3])[0]
        discount_pct = random.choices([0, 5, 10, 15, 20], weights=[55, 20, 12, 8, 5])[0]
        total = round(qty * unit_price * (1 - discount_pct / 100), 2)
        customer_id = customer[0] if customer else ""
        rows.append([sale_id, date_id, product_id, store[0], customer_id,
                     qty, unit_price, discount_pct, total])
    write_csv("fact_sales.csv",
              ["Sale_Id", "Date_Id", "Product_Id", "Store_Id", "Customer_Id",
               "Quantity_Sold", "Unit_Price", "Discount_Pct", "Total_Amount"], rows)
    return rows


def build_fact_inventory(date_id_map, product_rows, store_rows, sales_rows):
    # Aggregate quantity sold per (date, product, store) to keep inventory consistent
    sold_lookup = {}
    for r in sales_rows:
        key = (r[1], r[2], r[3])
        sold_lookup[key] = sold_lookup.get(key, 0) + r[5]

    rows = []
    inv_id = 1
    # sample a subset of dates (weekly snapshots) x all products x subset of stores
    dates_sorted = sorted(date_id_map.items())
    weekly_dates = dates_sorted[::7]
    sampled_stores = random.sample(store_rows, min(10, len(store_rows)))

    stock_state = {}
    for d, date_id in weekly_dates:
        for product in product_rows:
            for store in sampled_stores:
                key = (product[0], store[0])
                opening = stock_state.get(key, random.randint(20, 100))
                received = random.randint(0, 40)
                sold = sold_lookup.get((date_id, product[0], store[0]), 0)
                sold = min(sold, opening + received)
                closing = opening + received - sold
                stock_state[key] = closing
                rows.append([inv_id, date_id, product[0], store[0],
                             opening, received, sold, closing])
                inv_id += 1
    write_csv("fact_inventory.csv",
              ["Inventory_Id", "Date_Id", "Product_Id", "Store_Id",
               "Opening_Stock", "Received_Stock", "Sold_Stock", "Closing_Stock"], rows)


def main():
    date_id_map = build_dim_date()
    brand_ids = build_dim_brand()
    category_ids = build_dim_category()
    product_rows = build_dim_product(brand_ids, category_ids)
    store_rows = build_dim_store()
    customer_rows = build_dim_customer()
    sales_rows = build_fact_sales(date_id_map, product_rows, store_rows, customer_rows)
    build_fact_inventory(date_id_map, product_rows, store_rows, sales_rows)


if __name__ == "__main__":
    main()
