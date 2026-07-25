-- Part: 3 - Exploratory Data Analysis
-- Project - Zomato Delivery Operations Analytics
-- Author: Rishav Raj
-- run after 01_schema.sql and 02_data_cleaning.sql
--
-- basic exploratory queries, one metric at a time. numbered them
-- Q1, Q2... so it's easy to reference in the readme/report later.
-- added a line under each one saying what it's actually for, since
-- a raw query without context doesn't mean much on its own.
-- the more advanced stuff (window functions, CTEs) is in
-- 04_business_analysis.sql


-- ===================== DELIVERY TIME OVERVIEW =====================

-- Q1: overall average delivery time
-- this is the baseline number everything else gets compared to
SELECT ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders;


-- Q2: median delivery time
-- MySQL has no MEDIAN() function so doing it manually with a
-- prepared statement since LIMIT/OFFSET can't take a variable directly.
-- checking this against the average from Q1, if median is a lot
-- lower it means a few really slow deliveries are dragging the
-- average up rather than most deliveries actually being slow
SET @row_count  = (SELECT COUNT(*) FROM zomato_orders);
SET @offset_val = (@row_count - 1) DIV 2;
SET @limit_val  = 2 - (@row_count % 2);

PREPARE median_stmt FROM
    'SELECT AVG(time_taken_min) AS median_delivery_time
     FROM (SELECT time_taken_min FROM zomato_orders ORDER BY time_taken_min LIMIT ? OFFSET ?) AS middle_rows';
EXECUTE median_stmt USING @limit_val, @offset_val;
DEALLOCATE PREPARE median_stmt;


-- Q3: top 10 longest individual deliveries
-- want to see what's common between the worst cases, weather/traffic wise
SELECT
    id, delivery_person_id, city, type_of_vehicle,
    weather_conditions, road_traffic_density, time_taken_min
FROM zomato_orders
ORDER BY time_taken_min DESC
LIMIT 10;


-- Q4: top 10 shortest individual deliveries
-- basically the opposite of Q3, what does a best case order look like
SELECT
    id, delivery_person_id, city, type_of_vehicle,
    weather_conditions, road_traffic_density, time_taken_min
FROM zomato_orders
ORDER BY time_taken_min ASC
LIMIT 10;


-- ===================== TIME TRENDS =====================

-- Q5: monthly order count and avg delivery time
-- checking if delivery time is getting better or worse over the months
SELECT
    DATE_FORMAT(STR_TO_DATE(order_date, '%d-%m-%Y'), '%Y-%m') AS order_month,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
GROUP BY order_month
ORDER BY order_month;


-- Q6: weekend vs weekday
-- more orders on weekends probably means more strain on delivery times too
SELECT
    CASE
        WHEN DAYOFWEEK(STR_TO_DATE(order_date, '%d-%m-%Y')) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
GROUP BY day_type;


-- Q7: which hours get the most orders
-- useful for figuring out when more drivers are actually needed
SELECT
    HOUR(STR_TO_DATE(time_orderd, '%H:%i')) AS order_hour,
    COUNT(*) AS total_orders
FROM zomato_orders
WHERE time_orderd IS NOT NULL AND time_orderd <> ''
GROUP BY order_hour
ORDER BY total_orders DESC;


-- ===================== CITY / ZONE =====================
-- (using city as a stand-in for zone, see note in 01_schema.sql)

-- Q8: which cities get the most orders
SELECT city, COUNT(*) AS total_orders
FROM zomato_orders
WHERE city IS NOT NULL
GROUP BY city
ORDER BY total_orders DESC;


-- Q9: fastest city on average
SELECT city, ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE city IS NOT NULL
GROUP BY city
ORDER BY avg_delivery_time ASC
LIMIT 1;


-- Q10: slowest city on average
-- this is probably the city that needs the most attention
SELECT city, ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE city IS NOT NULL
GROUP BY city
ORDER BY avg_delivery_time DESC
LIMIT 1;


-- Q11: all cities together with volume, speed and rating
-- a city can look fine on speed but still have bad ratings, this
-- table is where that would actually show up
SELECT
    city,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
    ROUND(AVG(delivery_person_ratings), 2) AS avg_rating
FROM zomato_orders
WHERE city IS NOT NULL
GROUP BY city
ORDER BY avg_delivery_time ASC;


-- ===================== DRIVERS =====================

-- Q12: top 10 fastest drivers (min 5 deliveries so one lucky
-- order doesn't put someone at #1)
SELECT
    delivery_person_id,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
GROUP BY delivery_person_id
HAVING COUNT(*) >= 5
ORDER BY avg_delivery_time ASC
LIMIT 10;


-- Q13: top 10 slowest drivers, same 5 delivery minimum
SELECT
    delivery_person_id,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
GROUP BY delivery_person_id
HAVING COUNT(*) >= 5
ORDER BY avg_delivery_time DESC
LIMIT 10;


-- Q14: best rated drivers (min 5 deliveries)
-- comparing this list to Q12 to see if fast drivers are also the
-- highest rated ones or if it's two different sets of people
SELECT
    delivery_person_id,
    ROUND(AVG(delivery_person_ratings), 2) AS avg_rating,
    COUNT(*) AS total_deliveries
FROM zomato_orders
GROUP BY delivery_person_id
HAVING COUNT(*) >= 5
ORDER BY avg_rating DESC
LIMIT 10;


-- Q15: does a higher rating actually mean a faster driver?
-- bucketed ratings and compared avg delivery time across buckets
SELECT
    CASE
        WHEN delivery_person_ratings < 4.0 THEN 'Below 4.0'
        WHEN delivery_person_ratings < 4.5 THEN '4.0 - 4.5'
        WHEN delivery_person_ratings < 4.8 THEN '4.5 - 4.8'
        ELSE '4.8 and above'
    END AS rating_group,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE delivery_person_ratings IS NOT NULL
GROUP BY rating_group
ORDER BY avg_delivery_time;


-- Q16: driver age vs delivery time
SELECT
    delivery_person_age,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE delivery_person_age IS NOT NULL
GROUP BY delivery_person_age
ORDER BY delivery_person_age;


-- Q17: does carrying multiple deliveries at once slow drivers down?
SELECT
    multiple_deliveries,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE multiple_deliveries IS NOT NULL
GROUP BY multiple_deliveries
ORDER BY multiple_deliveries;


-- Q18: average number of deliveries handled per driver
SELECT ROUND(AVG(orders_per_driver), 2) AS avg_deliveries_per_driver
FROM (
    SELECT delivery_person_id, COUNT(*) AS orders_per_driver
    FROM zomato_orders
    GROUP BY delivery_person_id
) AS driver_counts;


-- ===================== WEATHER =====================

-- Q19: delivery time during fog
SELECT
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
    COUNT(*) AS total_orders
FROM zomato_orders
WHERE weather_conditions = 'Fog';


-- Q20: delivery time during storms
-- closest thing to "rain" in this dataset
SELECT
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
    COUNT(*) AS total_orders
FROM zomato_orders
WHERE weather_conditions = 'Stormy';


-- Q21: sunny vs stormy side by side
-- gives a rough number for how much bad weather actually costs
-- in delivery minutes
SELECT
    weather_conditions,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE weather_conditions IN ('Sunny', 'Stormy')
GROUP BY weather_conditions;


-- Q22: every weather condition ranked
SELECT
    weather_conditions,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE weather_conditions IS NOT NULL
GROUP BY weather_conditions
ORDER BY avg_delivery_time DESC;


-- ===================== TRAFFIC =====================

-- Q23: low vs high traffic side by side
SELECT
    road_traffic_density,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE road_traffic_density IN ('Low', 'High')
GROUP BY road_traffic_density;


-- Q24: all traffic levels ranked worst to best
SELECT
    road_traffic_density,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE road_traffic_density IS NOT NULL
GROUP BY road_traffic_density
ORDER BY avg_delivery_time DESC;


-- Q25: extra minutes each traffic level costs compared to "Low"
-- easier to actually use than just a ranking
SELECT
    road_traffic_density,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
    ROUND(AVG(time_taken_min) - (
        SELECT AVG(time_taken_min) FROM zomato_orders WHERE road_traffic_density = 'Low'
    ), 2) AS extra_minutes_vs_low_traffic
FROM zomato_orders
WHERE road_traffic_density IS NOT NULL
GROUP BY road_traffic_density
ORDER BY extra_minutes_vs_low_traffic DESC;


-- ===================== ORDER TYPE =====================
-- (Snack / Meal / Drinks / Buffet, no separate grocery category)

-- Q26: order type comparison
SELECT
    type_of_order,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
GROUP BY type_of_order
ORDER BY avg_delivery_time DESC;


-- Q27: single slowest order type
SELECT
    type_of_order,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
GROUP BY type_of_order
ORDER BY avg_delivery_time DESC
LIMIT 1;


-- ===================== VEHICLE =====================

-- Q28: motorcycle
SELECT ROUND(AVG(time_taken_min), 2) AS avg_delivery_time, COUNT(*) AS total_orders
FROM zomato_orders WHERE type_of_vehicle = 'motorcycle';

-- Q29: scooter
SELECT ROUND(AVG(time_taken_min), 2) AS avg_delivery_time, COUNT(*) AS total_orders
FROM zomato_orders WHERE type_of_vehicle = 'scooter';

-- Q30: bicycle
SELECT ROUND(AVG(time_taken_min), 2) AS avg_delivery_time, COUNT(*) AS total_orders
FROM zomato_orders WHERE type_of_vehicle = 'bicycle';

-- Q31: electric scooter
SELECT ROUND(AVG(time_taken_min), 2) AS avg_delivery_time, COUNT(*) AS total_orders
FROM zomato_orders WHERE type_of_vehicle = 'electric_scooter';

-- Q32: all 4 vehicle types together, fastest first
SELECT
    type_of_vehicle,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
GROUP BY type_of_vehicle
ORDER BY avg_delivery_time ASC;


-- Q33: average rating by vehicle type
-- checking against Q32, a vehicle that's fast but rated lower
-- probably means the issue isn't speed, it's something else
-- (food arriving messy, spilled, etc)
SELECT
    type_of_vehicle,
    ROUND(AVG(delivery_person_ratings), 2) AS avg_rating,
    COUNT(*) AS total_orders
FROM zomato_orders
GROUP BY type_of_vehicle
ORDER BY avg_rating DESC;


-- ===================== FESTIVAL =====================

-- Q34: avg delivery time, festival days vs normal days
SELECT
    festival,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
FROM zomato_orders
WHERE festival IS NOT NULL
GROUP BY festival;


-- Q35: order volume, festival vs normal
-- checking if festival days actually get more orders in this data
SELECT
    festival,
    COUNT(*) AS total_orders
FROM zomato_orders
WHERE festival IS NOT NULL
GROUP BY festival;


-- Q36: traffic mix on festival vs normal days
-- if festival days just have way more "Jam" traffic, that's probably
-- the real reason for the slowdown in Q34, not the festival itself
SELECT
    festival,
    road_traffic_density,
    COUNT(*) AS total_orders
FROM zomato_orders
WHERE festival IS NOT NULL AND road_traffic_density IS NOT NULL
GROUP BY festival, road_traffic_density
ORDER BY festival, total_orders DESC;
