🍽️ Food Delivery Marketplace Analytics — SQL Case Study
Advanced SQL | PostgreSQL | Business Analytics
📌 Overview
This project simulates the backend analytics function of a food delivery marketplace to solve real-world business problems using advanced SQL. Working across five relational tables — customers, restaurants, orders, deliveries, and riders — I designed the schema, cleaned the data, and answered 20+ business questions spanning customer behavior, restaurant performance, rider efficiency, and revenue growth.
The goal was to go beyond basic querying and demonstrate how SQL can directly support decisions around retention strategy, operational efficiency, and revenue recovery — the kind of analysis a data/business analyst would deliver to stakeholders.
🔑 Key Insights
Customer segmentation: Classified customers into Gold/Silver tiers using a spend-to-AOV (average order value) ratio, enabling targeted retention strategies for high-value customers.
Rider performance: Found that riders delivering in under 15 minutes achieved a 70%+ 5-star rating rate, directly linking delivery speed to customer satisfaction.
Revenue recovery: Identified an 8–10% recoverable revenue opportunity from undelivered orders by analyzing order-to-delivery drop-off across restaurants and cities.
Market performance: Ranked restaurants by city-wise revenue, tracked month-over-month growth, and compared cancellation rates year-over-year to flag underperforming outlets.
🗂️ Database Schema
The database (`food_delivery_db`) consists of five relational tables — `customers`, `restaurants`, `orders`, `deliveries`, and `riders` — linked through primary and foreign key relationships.
Entity Relationship Diagram:
![ERD](erd.png)
Table	Column	Type
customers	`customer_id` 🔑	serial
	`customer_name`	character varying(100)
	`reg_date`	date
restaurants	`restaurant_id` 🔑	serial
	`restaurant_name`	character varying(100)
	`city`	character varying(50)
	`opening_hours`	character varying(50)
orders	`order_id` 🔑	serial
	`customer_id` 🔗	integer
	`restaurant_id` 🔗	integer
	`order_item`	character varying(255)
	`order_date`	date
	`order_time`	time without time zone
	`order_status`	character varying(20)
	`total_amount`	numeric(10,2)
deliveries	`delivery_id` 🔑	serial
	`order_id` 🔗	integer
	`delivery_status`	character varying(20)
	`delivery_time`	time without time zone
	`rider_id` 🔗	integer
riders	`rider_id` 🔑	serial
	`rider_name`	character varying(100)
	`sign_up`	date
🔑 = Primary Key  🔗 = Foreign Key
Relationships:
`orders.customer_id` → `customers.customer_id` (one customer places many orders)
`orders.restaurant_id` → `restaurants.restaurant_id` (one restaurant fulfills many orders)
`deliveries.order_id` → `orders.order_id` (one order maps to one delivery)
`deliveries.rider_id` → `riders.rider_id` (one rider handles many deliveries)
```sql
CREATE TABLE restaurants (
    restaurant_id SERIAL PRIMARY KEY,
    restaurant_name VARCHAR(100) NOT NULL,
    city VARCHAR(50),
    opening_hours VARCHAR(50)
);

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    reg_date DATE
);

CREATE TABLE riders (
    rider_id SERIAL PRIMARY KEY,
    rider_name VARCHAR(100) NOT NULL,
    sign_up DATE
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT,
    restaurant_id INT,
    order_item VARCHAR(255),
    order_date DATE NOT NULL,
    order_time TIME NOT NULL,
    order_status VARCHAR(20) DEFAULT 'Pending',
    total_amount DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id)
);

CREATE TABLE deliveries (
    delivery_id SERIAL PRIMARY KEY,
    order_id INT,
    delivery_status VARCHAR(20) DEFAULT 'Pending',
    delivery_time TIME,
    rider_id INT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (rider_id) REFERENCES riders(rider_id)
);
```
🧹 Data Cleaning
Null values and data integrity issues were resolved before analysis, for example:
```sql
UPDATE orders
SET total_amount = COALESCE(total_amount, 0);
```
🛠️ SQL Techniques Used
Window functions: `RANK()`, `DENSE_RANK()`, `LAG()` for rankings, top-N analysis, and period-over-period comparisons
CTEs (Common Table Expressions): Multi-step logic for cancellation rate comparisons and growth calculations
Subqueries & correlated subqueries: Customer segmentation, churn detection
Conditional aggregation: `CASE WHEN` for rating tiers, seasonal buckets, and time-slot bucketing
Date/time functions: `EXTRACT`, `TO_CHAR`, interval arithmetic for delivery-time and cohort analysis
Joins: Multi-table joins (INNER, LEFT) across orders, restaurants, customers, deliveries, and riders
📊 Business Problems Solved
Top 5 most-ordered dishes by a specific customer in the last year
Peak ordering time slots (2-hour intervals)
Average order value for high-frequency customers (750+ orders)
High-value customers with lifetime spend over ₹100K
Orders placed but never delivered, by restaurant and city
Restaurant revenue ranking by city (trailing 12 months)
Most popular dish per city
Customer churn — active in 2023, inactive in 2024
Year-over-year cancellation rate comparison by restaurant
Average delivery time per rider
Month-over-month restaurant growth ratio (delivered orders)
Gold/Silver customer segmentation by spend-to-AOV ratio
Rider monthly earnings (8% commission model)
Rider star-rating distribution based on delivery speed
Peak order day of the week, per restaurant
Customer lifetime value (CLV)
Month-over-month sales trend analysis
Rider efficiency — fastest vs. slowest average delivery times
Seasonal demand trends by dish
City-wise revenue ranking (2023)
<details>
<summary><b>View full SQL solutions</b></summary>
1. Top 5 dishes ordered by a specific customer (last year)
```sql
SELECT customer_name, dishes, total_orders
FROM (
    SELECT 
        c.customer_id,
        c.customer_name,
        o.order_item AS dishes,
        COUNT(*) AS total_orders,
        DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS rank
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '1 year'
      AND c.customer_name = 'Arjun Mehta'
    GROUP BY 1, 2, 3
) t1
WHERE rank <= 5;
```
2. Peak order time slots (2-hour buckets)
```sql
SELECT 
    FLOOR(EXTRACT(HOUR FROM order_time) / 2) * 2 AS start_time,
    FLOOR(EXTRACT(HOUR FROM order_time) / 2) * 2 + 2 AS end_time,
    COUNT(*) AS total_orders
FROM orders
GROUP BY 1, 2
ORDER BY 3 DESC;
```
3. Average order value for high-frequency customers
```sql
SELECT c.customer_name, AVG(o.total_amount) AS aov
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY 1
HAVING COUNT(o.order_id) > 750;
```
4. High-value customers (₹100K+ lifetime spend)
```sql
SELECT c.customer_name, SUM(o.total_amount) AS total_spent
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY 1
HAVING SUM(o.total_amount) > 100000;
```
5. Orders placed but not delivered
```sql
SELECT r.restaurant_name, COUNT(o.order_id) AS cnt_not_delivered
FROM orders o
LEFT JOIN restaurants r ON r.restaurant_id = o.restaurant_id
LEFT JOIN deliveries d ON d.order_id = o.order_id
WHERE d.delivery_id IS NULL
GROUP BY 1
ORDER BY 2 DESC;
```
6. Restaurant revenue ranking by city
```sql
WITH ranking_table AS (
    SELECT 
        r.city,
        r.restaurant_name,
        SUM(o.total_amount) AS revenue,
        RANK() OVER (PARTITION BY r.city ORDER BY SUM(o.total_amount) DESC) AS rank
    FROM orders o
    JOIN restaurants r ON r.restaurant_id = o.restaurant_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '1 year'
    GROUP BY 1, 2
)
SELECT * FROM ranking_table WHERE rank = 1;
```
7. Most popular dish per city
```sql
SELECT * FROM (
    SELECT 
        r.city,
        o.order_item AS dish,
        COUNT(o.order_id) AS total_orders,
        RANK() OVER (PARTITION BY r.city ORDER BY COUNT(o.order_id) DESC) AS rank
    FROM orders o
    JOIN restaurants r ON r.restaurant_id = o.restaurant_id
    GROUP BY 1, 2
) t1
WHERE rank = 1;
```
8. Customer churn (active 2023, inactive 2024)
```sql
SELECT DISTINCT customer_id
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 2023
  AND customer_id NOT IN (
      SELECT DISTINCT customer_id FROM orders
      WHERE EXTRACT(YEAR FROM order_date) = 2024
  );
```
9. Year-over-year cancellation rate comparison
```sql
WITH cancel_ratio_23 AS (
    SELECT o.restaurant_id,
        COUNT(o.order_id) AS total_orders,
        COUNT(CASE WHEN d.delivery_id IS NULL THEN 1 END) AS not_delivered
    FROM orders o
    LEFT JOIN deliveries d ON o.order_id = d.order_id
    WHERE EXTRACT(YEAR FROM o.order_date) = 2023
    GROUP BY o.restaurant_id
),
cancel_ratio_24 AS (
    SELECT o.restaurant_id,
        COUNT(o.order_id) AS total_orders,
        COUNT(CASE WHEN d.delivery_id IS NULL THEN 1 END) AS not_delivered
    FROM orders o
    LEFT JOIN deliveries d ON o.order_id = d.order_id
    WHERE EXTRACT(YEAR FROM o.order_date) = 2024
    GROUP BY o.restaurant_id
),
last_year_data AS (
    SELECT restaurant_id, total_orders, not_delivered,
        ROUND((not_delivered::numeric / total_orders::numeric) * 100, 2) AS cancel_ratio
    FROM cancel_ratio_23
),
current_year_data AS (
    SELECT restaurant_id, total_orders, not_delivered,
        ROUND((not_delivered::numeric / total_orders::numeric) * 100, 2) AS cancel_ratio
    FROM cancel_ratio_24
)
SELECT c.restaurant_id, c.cancel_ratio AS current_year_cancel_ratio, l.cancel_ratio AS last_year_cancel_ratio
FROM current_year_data c
JOIN last_year_data l ON c.restaurant_id = l.restaurant_id;
```
10. Average delivery time per rider
```sql
SELECT 
    o.order_id, o.order_time, d.delivery_time, d.rider_id,
    EXTRACT(EPOCH FROM (d.delivery_time - o.order_time +
        CASE WHEN d.delivery_time < o.order_time THEN INTERVAL '1 day' ELSE INTERVAL '0 day' END)) / 60 AS time_diff_minutes
FROM orders o
JOIN deliveries d ON o.order_id = d.order_id
WHERE d.delivery_status = 'Delivered';
```
11. Month-over-month restaurant growth ratio
```sql
WITH growth_ratio AS (
    SELECT 
        o.restaurant_id,
        EXTRACT(YEAR FROM o.order_date) AS year,
        EXTRACT(MONTH FROM o.order_date) AS month,
        COUNT(o.order_id) AS cr_month_orders,
        LAG(COUNT(o.order_id), 1) OVER (
            PARTITION BY o.restaurant_id 
            ORDER BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
        ) AS prev_month_orders
    FROM orders o
    JOIN deliveries d ON o.order_id = d.order_id
    WHERE d.delivery_status = 'Delivered'
    GROUP BY 1, 2, 3
)
SELECT 
    restaurant_id, month, prev_month_orders, cr_month_orders,
    ROUND((cr_month_orders::numeric - prev_month_orders::numeric) / prev_month_orders::numeric * 100, 2) AS growth_ratio
FROM growth_ratio;
```
12. Gold/Silver customer segmentation
```sql
SELECT cx_category, SUM(total_orders) AS total_orders, SUM(total_spent) AS total_revenue
FROM (
    SELECT 
        customer_id,
        SUM(total_amount) AS total_spent,
        COUNT(order_id) AS total_orders,
        CASE 
            WHEN SUM(total_amount) > (SELECT AVG(total_amount) FROM orders) THEN 'Gold'
            ELSE 'Silver'
        END AS cx_category
    FROM orders
    GROUP BY 1
) t1
GROUP BY 1;
```
13. Rider monthly earnings (8% commission)
```sql
SELECT 
    d.rider_id,
    TO_CHAR(o.order_date, 'mm-yy') AS month,
    SUM(total_amount) AS revenue,
    SUM(total_amount) * 0.08 AS riders_earning
FROM orders o
JOIN deliveries d ON o.order_id = d.order_id
GROUP BY 1, 2
ORDER BY 1, 2;
```
14. Rider star-rating distribution
```sql
SELECT rider_id, stars, COUNT(*) AS total_stars
FROM (
    SELECT rider_id, delivery_took_time,
        CASE 
            WHEN delivery_took_time < 15 THEN '5 star'
            WHEN delivery_took_time BETWEEN 15 AND 20 THEN '4 star'
            ELSE '3 star'
        END AS stars
    FROM (
        SELECT 
            o.order_id, o.order_time, d.delivery_time,
            EXTRACT(EPOCH FROM (d.delivery_time - o.order_time +
                CASE WHEN d.delivery_time < o.order_time THEN INTERVAL '1 day' ELSE INTERVAL '0 day' END)) / 60 AS delivery_took_time,
            d.rider_id
        FROM orders o
        JOIN deliveries d ON o.order_id = d.order_id
        WHERE delivery_status = 'Delivered'
    ) t1
) t2
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
```
15. Peak order day per restaurant
```sql
SELECT * FROM (
    SELECT 
        r.restaurant_name,
        TO_CHAR(o.order_date, 'Day') AS day,
        COUNT(o.order_id) AS total_orders,
        RANK() OVER (PARTITION BY r.restaurant_name ORDER BY COUNT(o.order_id) DESC) AS rank
    FROM orders o
    JOIN restaurants r ON o.restaurant_id = r.restaurant_id
    GROUP BY 1, 2
) t1
WHERE rank = 1;
```
16. Customer Lifetime Value (CLV)
```sql
SELECT o.customer_id, c.customer_name, SUM(o.total_amount) AS clv
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY 1, 2;
```
17. Month-over-month sales trend
```sql
SELECT 
    EXTRACT(YEAR FROM order_date) AS year,
    EXTRACT(MONTH FROM order_date) AS month,
    SUM(total_amount) AS total_sale,
    LAG(SUM(total_amount), 1) OVER (
        ORDER BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
    ) AS prev_month_sale
FROM orders
GROUP BY 1, 2;
```
18. Rider efficiency (fastest vs. slowest)
```sql
WITH delivery_times AS (
    SELECT 
        d.rider_id,
        EXTRACT(EPOCH FROM (d.delivery_time - o.order_time +
            CASE WHEN d.delivery_time < o.order_time THEN INTERVAL '1 day' ELSE INTERVAL '0 day' END)) / 60 AS time_taken
    FROM orders o
    JOIN deliveries d ON o.order_id = d.order_id
    WHERE d.delivery_status = 'Delivered'
),
rider_avg AS (
    SELECT rider_id, AVG(time_taken) AS avg_time
    FROM delivery_times
    GROUP BY 1
)
SELECT MIN(avg_time) AS fastest_avg, MAX(avg_time) AS slowest_avg
FROM rider_avg;
```
19. Seasonal demand by dish
```sql
SELECT order_item, seasons, COUNT(order_id) AS total_orders
FROM (
    SELECT *,
        CASE 
            WHEN EXTRACT(MONTH FROM order_date) BETWEEN 4 AND 6 THEN 'Spring'
            WHEN EXTRACT(MONTH FROM order_date) > 6 AND EXTRACT(MONTH FROM order_date) < 9 THEN 'Summer'
            ELSE 'Winter'
        END AS seasons
    FROM orders
) t1
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
```
20. City-wise revenue ranking (2023)
```sql
SELECT 
    r.city,
    SUM(total_amount) AS total_revenue,
    RANK() OVER (ORDER BY SUM(total_amount) DESC) AS city_rank
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
GROUP BY 1;
```
</details>
🧰 Tech Stack
Database: PostgreSQL
Concepts: CTEs, window functions, subqueries, conditional aggregation, joins, date/time functions
📁 Repository Structure
```
├── data/
│   ├── customers.csv
│   ├── restaurants.csv
│   ├── orders.csv
│   ├── deliveries.csv
│   └── riders.csv
├── database_setup.sql        -- schema creation
├── business_problems.sql     -- all 20 solved queries
├── erd.png                   -- entity relationship diagram
└── README.md
```
🎯 Key Takeaway
This project reflects an end-to-end analytics workflow — from schema design and data cleaning to writing production-style SQL that answers concrete business questions around retention, operational efficiency, and revenue recovery — the same kind of analysis used to drive decisions in a real food-delivery marketplace.
---
Note: All data used in this project is synthetically generated for educational purposes and does not represent real data associated with any specific company or entity.
