/*
===============================================================================
 Food Delivery Platform — Advanced SQL Business Analytics
===============================================================================
 Description : End-to-end SQL analysis on a food delivery platform dataset
               covering customers, restaurants, orders, riders, and deliveries.
               The queries answer 20 real-world business questions spanning
               customer behavior, restaurant performance, delivery operations,
               and revenue analytics.

 Tables Used : customers, restaurants, orders, riders, deliveries

 Author      : [Your Name]
===============================================================================
*/

-- ===============================================================
-- SECTION 0: DATA QUALITY CHECKS & CLEANING
-- ===============================================================

-- 0.1 Identify incomplete customer records
SELECT COUNT(*) AS incomplete_customer_records
FROM customers
WHERE customer_name IS NULL
   OR reg_date IS NULL;

-- 0.2 Identify incomplete restaurant records
SELECT COUNT(*) AS incomplete_restaurant_records
FROM restaurants
WHERE restaurant_name IS NULL
   OR city IS NULL
   OR opening_hours IS NULL;

-- 0.3 Identify incomplete order records
SELECT *
FROM orders
WHERE order_item IS NULL
   OR order_date IS NULL
   OR order_time IS NULL
   OR order_status IS NULL
   OR total_amount IS NULL;

-- 0.4 Remove incomplete order records
DELETE FROM orders
WHERE order_item IS NULL
   OR order_date IS NULL
   OR order_time IS NULL
   OR order_status IS NULL
   OR total_amount IS NULL;


-- ===============================================================
-- SECTION 1: CUSTOMER INSIGHTS
-- ===============================================================

-- 1.1 Top 5 most frequently ordered dishes by a specific customer
--     over the last 12 months.
SELECT
    customer_name,
    dishes,
    total_orders
FROM (
    SELECT
        c.customer_id,
        c.customer_name,
        o.order_item                                       AS dishes,
        COUNT(*)                                            AS total_orders,
        DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)           AS dish_rank
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '1 year'
      AND c.customer_name = 'Target Customer Name'   -- parameterize as needed
    GROUP BY c.customer_id, c.customer_name, o.order_item
) ranked_dishes
WHERE dish_rank <= 5;


-- 1.2 Customers whose spend qualifies them as high-value (> 100,000 lifetime).
SELECT
    c.customer_id,
    c.customer_name,
    SUM(o.total_amount) AS total_spent
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING SUM(o.total_amount) > 100000;


-- 1.3 Average order value (AOV) for customers with high order volume (> 750 orders).
SELECT
    c.customer_name,
    AVG(o.total_amount) AS avg_order_value
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
GROUP BY c.customer_name
HAVING COUNT(o.order_id) > 750;


-- 1.4 Customer churn: active in the prior year but inactive in the current year.
SELECT DISTINCT customer_id
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 2023
  AND customer_id NOT IN (
        SELECT DISTINCT customer_id
        FROM orders
        WHERE EXTRACT(YEAR FROM order_date) = 2024
  );


-- 1.5 Customer segmentation — Gold vs Silver based on spend relative to
--     platform-wide average order value.
SELECT
    customer_segment,
    SUM(total_orders) AS total_orders,
    SUM(total_spent)  AS total_revenue
FROM (
    SELECT
        customer_id,
        SUM(total_amount) AS total_spent,
        COUNT(order_id)    AS total_orders,
        CASE
            WHEN SUM(total_amount) > (SELECT AVG(total_amount) FROM orders)
                THEN 'Gold'
            ELSE 'Silver'
        END AS customer_segment
    FROM orders
    GROUP BY customer_id
) segmented_customers
GROUP BY customer_segment;


-- 1.6 Customer Lifetime Value (CLV) — total revenue generated per customer.
SELECT
    o.customer_id,
    c.customer_name,
    SUM(o.total_amount) AS customer_lifetime_value
FROM orders AS o
JOIN customers AS c
    ON o.customer_id = c.customer_id
GROUP BY o.customer_id, c.customer_name;


-- ===============================================================
-- SECTION 2: ORDER & DEMAND PATTERNS
-- ===============================================================

-- 2.1 Peak ordering time slots, bucketed into 2-hour intervals.
SELECT
    FLOOR(EXTRACT(HOUR FROM order_time) / 2) * 2       AS slot_start_hour,
    FLOOR(EXTRACT(HOUR FROM order_time) / 2) * 2 + 2    AS slot_end_hour,
    COUNT(*)                                             AS total_orders
FROM orders
GROUP BY slot_start_hour, slot_end_hour
ORDER BY total_orders DESC;


-- 2.2 Order frequency by day of week, with peak day identified per restaurant.
SELECT *
FROM (
    SELECT
        r.restaurant_name,
        TO_CHAR(o.order_date, 'Day')                                        AS order_day,
        COUNT(o.order_id)                                                    AS total_orders,
        RANK() OVER (PARTITION BY r.restaurant_name ORDER BY COUNT(o.order_id) DESC) AS day_rank
    FROM orders AS o
    JOIN restaurants AS r
        ON o.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_name, order_day
) daily_orders
WHERE day_rank = 1;


-- 2.3 Seasonal demand patterns by order item.
SELECT
    order_item,
    season,
    COUNT(order_id) AS total_orders
FROM (
    SELECT
        *,
        CASE
            WHEN EXTRACT(MONTH FROM order_date) BETWEEN 4 AND 6 THEN 'Spring'
            WHEN EXTRACT(MONTH FROM order_date) BETWEEN 7 AND 8 THEN 'Summer'
            ELSE 'Winter'
        END AS season
    FROM orders
) seasonal_orders
GROUP BY order_item, season
ORDER BY order_item, total_orders DESC;


-- 2.4 Monthly sales trend — current month vs. prior month.
SELECT
    EXTRACT(YEAR FROM order_date)  AS order_year,
    EXTRACT(MONTH FROM order_date) AS order_month,
    SUM(total_amount)               AS monthly_sales,
    LAG(SUM(total_amount), 1) OVER (
        ORDER BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
    ) AS prev_month_sales
FROM orders
GROUP BY order_year, order_month
ORDER BY order_year, order_month;


-- ===============================================================
-- SECTION 3: RESTAURANT PERFORMANCE
-- ===============================================================

-- 3.1 Restaurant revenue ranking within each city over the last year.
WITH revenue_ranking AS (
    SELECT
        r.city,
        r.restaurant_name,
        SUM(o.total_amount) AS revenue,
        RANK() OVER (PARTITION BY r.city ORDER BY SUM(o.total_amount) DESC) AS city_rank
    FROM orders AS o
    JOIN restaurants AS r
        ON r.restaurant_id = o.restaurant_id
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '1 year'
    GROUP BY r.city, r.restaurant_name
)
SELECT *
FROM revenue_ranking
WHERE city_rank = 1;


-- 3.2 Most popular dish per city, by order volume.
SELECT *
FROM (
    SELECT
        r.city,
        o.order_item AS dish,
        COUNT(o.order_id) AS total_orders,
        RANK() OVER (PARTITION BY r.city ORDER BY COUNT(o.order_id) DESC) AS dish_rank
    FROM orders AS o
    JOIN restaurants AS r
        ON r.restaurant_id = o.restaurant_id
    GROUP BY r.city, o.order_item
) city_dishes
WHERE dish_rank = 1;


-- 3.3 Orders placed but never fulfilled, by restaurant.
SELECT
    r.restaurant_name,
    COUNT(o.order_id) AS undelivered_orders
FROM orders AS o
LEFT JOIN restaurants AS r
    ON r.restaurant_id = o.restaurant_id
WHERE o.order_id NOT IN (SELECT order_id FROM deliveries)
GROUP BY r.restaurant_name
ORDER BY undelivered_orders DESC;


-- 3.4 Year-over-year cancellation rate comparison, by restaurant.
WITH cancel_stats_prior_year AS (
    SELECT
        o.restaurant_id,
        COUNT(o.order_id) AS total_orders,
        COUNT(CASE WHEN d.delivery_id IS NULL THEN 1 END) AS cancelled_orders
    FROM orders AS o
    LEFT JOIN deliveries AS d
        ON o.order_id = d.order_id
    WHERE EXTRACT(YEAR FROM o.order_date) = 2023
    GROUP BY o.restaurant_id
),
cancel_stats_current_year AS (
    SELECT
        o.restaurant_id,
        COUNT(o.order_id) AS total_orders,
        COUNT(CASE WHEN d.delivery_id IS NULL THEN 1 END) AS cancelled_orders
    FROM orders AS o
    LEFT JOIN deliveries AS d
        ON o.order_id = d.order_id
    WHERE EXTRACT(YEAR FROM o.order_date) = 2024
    GROUP BY o.restaurant_id
),
prior_year_ratio AS (
    SELECT
        restaurant_id,
        ROUND((cancelled_orders::numeric / total_orders::numeric) * 100, 2) AS cancellation_rate
    FROM cancel_stats_prior_year
),
current_year_ratio AS (
    SELECT
        restaurant_id,
        ROUND((cancelled_orders::numeric / total_orders::numeric) * 100, 2) AS cancellation_rate
    FROM cancel_stats_current_year
)
SELECT
    c.restaurant_id,
    c.cancellation_rate AS current_year_cancellation_rate,
    p.cancellation_rate AS prior_year_cancellation_rate
FROM current_year_ratio AS c
JOIN prior_year_ratio AS p
    ON c.restaurant_id = p.restaurant_id;


-- 3.5 Month-over-month growth rate in delivered order volume, by restaurant.
WITH monthly_orders AS (
    SELECT
        o.restaurant_id,
        EXTRACT(YEAR FROM o.order_date)  AS order_year,
        EXTRACT(MONTH FROM o.order_date) AS order_month,
        COUNT(o.order_id) AS current_month_orders,
        LAG(COUNT(o.order_id), 1) OVER (
            PARTITION BY o.restaurant_id
            ORDER BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
        ) AS previous_month_orders
    FROM orders AS o
    JOIN deliveries AS d
        ON o.order_id = d.order_id
    WHERE d.delivery_status = 'Delivered'
    GROUP BY o.restaurant_id, order_year, order_month
)
SELECT
    restaurant_id,
    order_year,
    order_month,
    previous_month_orders,
    current_month_orders,
    ROUND(
        (current_month_orders::numeric - previous_month_orders::numeric)
        / previous_month_orders::numeric * 100, 2
    ) AS growth_rate_pct
FROM monthly_orders;


-- ===============================================================
-- SECTION 4: DELIVERY & RIDER OPERATIONS
-- ===============================================================

-- 4.1 Average delivery time per completed order.
SELECT
    o.order_id,
    o.order_time,
    d.delivery_time,
    d.rider_id,
    EXTRACT(EPOCH FROM (
        d.delivery_time - o.order_time
        + CASE WHEN d.delivery_time < o.order_time THEN INTERVAL '1 day' ELSE INTERVAL '0 day' END
    )) / 60 AS delivery_duration_minutes
FROM orders AS o
JOIN deliveries AS d
    ON o.order_id = d.order_id
WHERE d.delivery_status = 'Delivered';


-- 4.2 Rider efficiency — fastest and slowest average delivery times.
WITH delivery_durations AS (
    SELECT
        d.rider_id,
        EXTRACT(EPOCH FROM (
            d.delivery_time - o.order_time
            + CASE WHEN d.delivery_time < o.order_time THEN INTERVAL '1 day' ELSE INTERVAL '0 day' END
        )) / 60 AS delivery_duration_minutes
    FROM orders AS o
    JOIN deliveries AS d
        ON o.order_id = d.order_id
    WHERE d.delivery_status = 'Delivered'
),
rider_avg_time AS (
    SELECT
        rider_id,
        AVG(delivery_duration_minutes) AS avg_delivery_time
    FROM delivery_durations
    GROUP BY rider_id
)
SELECT
    MIN(avg_delivery_time) AS fastest_avg_delivery_time,
    MAX(avg_delivery_time) AS slowest_avg_delivery_time
FROM rider_avg_time;


-- 4.3 Rider star-rating distribution, derived from delivery speed.
--     < 15 min = 5-star | 15-20 min = 4-star | > 20 min = 3-star
SELECT
    rider_id,
    rating_tier,
    COUNT(*) AS total_ratings
FROM (
    SELECT
        rider_id,
        delivery_duration_minutes,
        CASE
            WHEN delivery_duration_minutes < 15 THEN '5 Star'
            WHEN delivery_duration_minutes BETWEEN 15 AND 20 THEN '4 Star'
            ELSE '3 Star'
        END AS rating_tier
    FROM (
        SELECT
            d.rider_id,
            EXTRACT(EPOCH FROM (
                d.delivery_time - o.order_time
                + CASE WHEN d.delivery_time < o.order_time THEN INTERVAL '1 day' ELSE INTERVAL '0 day' END
            )) / 60 AS delivery_duration_minutes
        FROM orders AS o
        JOIN deliveries AS d
            ON o.order_id = d.order_id
        WHERE d.delivery_status = 'Delivered'
    ) delivery_times
) rated_deliveries
GROUP BY rider_id, rating_tier
ORDER BY rider_id, total_ratings DESC;


-- 4.4 Rider monthly earnings, assuming an 8% commission on order value.
SELECT
    d.rider_id,
    TO_CHAR(o.order_date, 'MM-YYYY') AS earning_month,
    SUM(o.total_amount)               AS orders_value,
    ROUND(SUM(o.total_amount) * 0.08, 2) AS rider_earnings
FROM orders AS o
JOIN deliveries AS d
    ON o.order_id = d.order_id
GROUP BY d.rider_id, earning_month
ORDER BY d.rider_id, earning_month;


-- ===============================================================
-- SECTION 5: CITY-LEVEL REVENUE ANALYSIS
-- ===============================================================

-- 5.1 City ranking by total revenue.
SELECT
    r.city,
    SUM(o.total_amount) AS total_revenue,
    RANK() OVER (ORDER BY SUM(o.total_amount) DESC) AS city_revenue_rank
FROM orders AS o
JOIN restaurants AS r
    ON o.restaurant_id = r.restaurant_id
GROUP BY r.city;

-- ===============================================================
-- END OF ANALYSIS
-- ===============================================================
