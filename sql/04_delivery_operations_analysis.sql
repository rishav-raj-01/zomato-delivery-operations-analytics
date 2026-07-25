-- Part: 4 - Delivery Operations Analysis
-- Project - Zomato Delivery Operations Analytics
-- Author: Rishav Raj
-- run after 01_schema.sql and 02_data_cleaning.sql
--
-- this file goes a bit deeper than 03_eda_queries.sql, using CTEs
-- and window functions instead of plain GROUP BY. numbered these
-- Q37 onward so the numbering carries on from the eda file.


-- Q37: rank every driver's speed within their own city
-- a driver stuck in a slow, high traffic city will always look bad
-- next to one working in an easy city, so comparing them within
-- the same city feels more fair
WITH driver_city_stats AS (
    SELECT
        delivery_person_id,
        city,
        COUNT(*) AS total_deliveries,
        ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
    FROM zomato_orders
    WHERE city IS NOT NULL
    GROUP BY delivery_person_id, city
    HAVING COUNT(*) >= 5
)
SELECT
    delivery_person_id,
    city,
    total_deliveries,
    avg_delivery_time,
    RANK() OVER (PARTITION BY city ORDER BY avg_delivery_time ASC) AS speed_rank_in_city
FROM driver_city_stats
ORDER BY city, speed_rank_in_city
LIMIT 50;


-- Q38: split all drivers into 4 speed groups using NTILE
-- basically dividing the whole driver list into quarters, fastest
-- quarter to slowest quarter, could be used for something like
-- a bonus for the top group and extra training for the bottom one
WITH driver_avg AS (
    SELECT
        delivery_person_id,
        COUNT(*) AS total_deliveries,
        ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
    FROM zomato_orders
    GROUP BY delivery_person_id
    HAVING COUNT(*) >= 5
)
SELECT
    delivery_person_id,
    total_deliveries,
    avg_delivery_time,
    NTILE(4) OVER (ORDER BY avg_delivery_time ASC) AS speed_quartile
FROM driver_avg
ORDER BY speed_quartile, avg_delivery_time;


-- Q39: which drivers are fast AND consistent (low STDDEV)
-- a driver can have a good average but still be all over the place
-- trip to trip, this checks for drivers who are both quick and steady
SELECT
    delivery_person_id,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
    ROUND(STDDEV(time_taken_min), 2) AS delivery_time_stddev
FROM zomato_orders
GROUP BY delivery_person_id
HAVING COUNT(*) >= 5
ORDER BY delivery_time_stddev ASC, avg_delivery_time ASC
LIMIT 15;


-- Q40: find drivers who are more than 1 standard deviation slower
-- than the fleet average, instead of just picking an arbitrary
-- "bottom 10" list, this at least has some statistical basis to it
WITH fleet_stats AS (
    SELECT
        AVG(time_taken_min) AS fleet_avg,
        STDDEV(time_taken_min) AS fleet_stddev
    FROM zomato_orders
),
driver_avg AS (
    SELECT
        delivery_person_id,
        COUNT(*) AS total_deliveries,
        AVG(time_taken_min) AS avg_delivery_time
    FROM zomato_orders
    GROUP BY delivery_person_id
    HAVING COUNT(*) >= 5
)
SELECT
    d.delivery_person_id,
    d.total_deliveries,
    ROUND(d.avg_delivery_time, 2) AS avg_delivery_time,
    ROUND(f.fleet_avg, 2) AS fleet_avg_delivery_time,
    ROUND(d.avg_delivery_time - f.fleet_avg, 2) AS minutes_above_fleet_avg
FROM driver_avg d
CROSS JOIN fleet_stats f
WHERE d.avg_delivery_time > f.fleet_avg + f.fleet_stddev
ORDER BY minutes_above_fleet_avg DESC;


-- Q41: what percentile is each driver's rating in
-- easier to explain to someone as "you're in the top 15%" than
-- just throwing a raw average number at them
SELECT
    delivery_person_id,
    ROUND(AVG(delivery_person_ratings), 2) AS avg_rating,
    COUNT(*) AS total_deliveries,
    ROUND(PERCENT_RANK() OVER (ORDER BY AVG(delivery_person_ratings) ASC), 3) AS rating_percentile
FROM zomato_orders
WHERE delivery_person_ratings IS NOT NULL
GROUP BY delivery_person_id
HAVING COUNT(*) >= 5
ORDER BY rating_percentile DESC
LIMIT 20;


-- Q42: month over month order growth, using LAG to grab the
-- previous month's numbers in the same row
WITH monthly AS (
    SELECT
        DATE_FORMAT(STR_TO_DATE(order_date, '%d-%m-%Y'), '%Y-%m') AS order_month,
        COUNT(*) AS total_orders,
        ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
    FROM zomato_orders
    WHERE order_date IS NOT NULL
    GROUP BY order_month
)
SELECT
    order_month,
    total_orders,
    avg_delivery_time,
    LAG(total_orders) OVER (ORDER BY order_month) AS prev_month_orders,
    ROUND(
        (total_orders - LAG(total_orders) OVER (ORDER BY order_month))
        / LAG(total_orders) OVER (ORDER BY order_month) * 100
    , 2) AS order_growth_pct,
    ROUND(
        avg_delivery_time - LAG(avg_delivery_time) OVER (ORDER BY order_month)
    , 2) AS delivery_time_change_min
FROM monthly
ORDER BY order_month;


-- Q43: 3 month rolling average delivery time
-- smooths out a single bad month (like one with a lot of storms)
-- so I can actually tell if things are improving overall or not
WITH monthly AS (
    SELECT
        DATE_FORMAT(STR_TO_DATE(order_date, '%d-%m-%Y'), '%Y-%m') AS order_month,
        ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
    FROM zomato_orders
    WHERE order_date IS NOT NULL
    GROUP BY order_month
)
SELECT
    order_month,
    avg_delivery_time,
    ROUND(AVG(avg_delivery_time) OVER (
        ORDER BY order_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3month_avg_delivery_time
FROM monthly
ORDER BY order_month;


-- Q44: rank every weather + traffic combo by how slow it is
-- weather or traffic alone don't tell the full story, want to see
-- which combination together is actually the worst
SELECT
    weather_conditions,
    road_traffic_density,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
    DENSE_RANK() OVER (ORDER BY AVG(time_taken_min) DESC) AS severity_rank
FROM zomato_orders
WHERE weather_conditions IS NOT NULL
  AND road_traffic_density IS NOT NULL
GROUP BY weather_conditions, road_traffic_density
HAVING COUNT(*) >= 30   -- ignoring combos with too few orders to trust
ORDER BY severity_rank;


-- Q45: exactly how much slower is a festival day vs normal, in
-- both minutes and percent, using MIN() as a window function to
-- pull the normal-day baseline into the same row
WITH festival_stats AS (
    SELECT
        festival,
        ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
        COUNT(*) AS total_orders
    FROM zomato_orders
    WHERE festival IS NOT NULL
    GROUP BY festival
)
SELECT
    festival,
    avg_delivery_time,
    total_orders,
    avg_delivery_time - MIN(avg_delivery_time) OVER () AS extra_minutes_vs_normal_day,
    ROUND(
        (avg_delivery_time - MIN(avg_delivery_time) OVER ())
        / MIN(avg_delivery_time) OVER () * 100
    , 2) AS pct_slower_vs_normal_day
FROM festival_stats;


-- Q46: made this a view so I don't have to rewrite the same
-- city query every time, could plug this straight into Power BI
-- or Tableau later
CREATE OR REPLACE VIEW city_performance_summary AS
SELECT
    city,
    COUNT(*) AS total_orders,
    ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
    ROUND(AVG(delivery_person_ratings), 2) AS avg_rating,
    DENSE_RANK() OVER (ORDER BY AVG(time_taken_min) ASC) AS speed_rank,
    DENSE_RANK() OVER (ORDER BY AVG(delivery_person_ratings) DESC) AS rating_rank
FROM zomato_orders
WHERE city IS NOT NULL
GROUP BY city;

-- example:
-- SELECT * FROM city_performance_summary ORDER BY speed_rank;


-- Q47: cities where speed rank and rating rank don't match up
-- if a city is fast but still rated badly (or the other way round),
-- the problem probably isn't delivery time at all
SELECT
    city,
    total_orders,
    avg_delivery_time,
    avg_rating,
    speed_rank,
    rating_rank,
    (rating_rank - speed_rank) AS rank_gap
FROM city_performance_summary
ORDER BY ABS(rating_rank - speed_rank) DESC;


-- Q48: rank vehicle types on speed, rating and volume all at once
-- adding the 3 ranks together so one vehicle type doesn't win
-- just because it's fast but actually has bad ratings
WITH vehicle_stats AS (
    SELECT
        type_of_vehicle,
        COUNT(*) AS total_orders,
        ROUND(AVG(time_taken_min), 2) AS avg_delivery_time,
        ROUND(AVG(delivery_person_ratings), 2) AS avg_rating
    FROM zomato_orders
    GROUP BY type_of_vehicle
)
SELECT
    type_of_vehicle,
    total_orders,
    avg_delivery_time,
    avg_rating,
    RANK() OVER (ORDER BY avg_delivery_time ASC)  AS speed_rank,
    RANK() OVER (ORDER BY avg_rating DESC)         AS rating_rank,
    RANK() OVER (ORDER BY total_orders DESC)       AS volume_rank,
    (RANK() OVER (ORDER BY avg_delivery_time ASC)
     + RANK() OVER (ORDER BY avg_rating DESC)
     + RANK() OVER (ORDER BY total_orders DESC))   AS rank_total
FROM vehicle_stats
ORDER BY rank_total ASC;


-- Q49: driver speed ranked only against other drivers who also
-- got stuck in "Jam" traffic, so it's an apples to apples comparison
-- instead of comparing everyone regardless of what traffic they got
WITH driver_traffic_stats AS (
    SELECT
        delivery_person_id,
        road_traffic_density,
        COUNT(*) AS total_deliveries,
        ROUND(AVG(time_taken_min), 2) AS avg_delivery_time
    FROM zomato_orders
    WHERE road_traffic_density IS NOT NULL
    GROUP BY delivery_person_id, road_traffic_density
    HAVING COUNT(*) >= 5
)
SELECT
    delivery_person_id,
    road_traffic_density,
    total_deliveries,
    avg_delivery_time,
    RANK() OVER (
        PARTITION BY road_traffic_density
        ORDER BY avg_delivery_time ASC
    ) AS speed_rank_within_traffic_level
FROM driver_traffic_stats
WHERE road_traffic_density = 'Jam'
ORDER BY speed_rank_within_traffic_level
LIMIT 15;
