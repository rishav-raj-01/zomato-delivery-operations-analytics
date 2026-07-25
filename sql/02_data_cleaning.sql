-- Part: 2 - data cleaning
-- Project - Zomato Delivery Operations Analytics
-- Author: Rishav Raj
-- run this after 01_schema.sql and after the csv is loaded

-- fixes the literal "NaN" text -> real NULL, converts the text columns
-- to actual numbers, then a few sanity checks so I know the data is
-- actually clean before running numbers on top of it


-- turn "NaN" text into real NULLs
UPDATE zomato_orders SET delivery_person_age     = NULL WHERE delivery_person_age     = 'NaN';
UPDATE zomato_orders SET delivery_person_ratings = NULL WHERE delivery_person_ratings = 'NaN';
UPDATE zomato_orders SET time_orderd             = NULL WHERE time_orderd             = 'NaN';
UPDATE zomato_orders SET weather_conditions      = NULL WHERE weather_conditions      = 'NaN';
UPDATE zomato_orders SET road_traffic_density    = NULL WHERE road_traffic_density    = 'NaN';
UPDATE zomato_orders SET multiple_deliveries     = NULL WHERE multiple_deliveries     = 'NaN';
UPDATE zomato_orders SET festival                = NULL WHERE festival                = 'NaN';
UPDATE zomato_orders SET city                    = NULL WHERE city                    = 'NaN';

-- also trimming whitespace, csv exports from pandas sometimes leave
-- trailing spaces on text columns (e.g. "Jam " vs "Jam") which would
-- otherwise mess up the GROUP BY later
UPDATE zomato_orders SET weather_conditions   = TRIM(weather_conditions);
UPDATE zomato_orders SET road_traffic_density = TRIM(road_traffic_density);
UPDATE zomato_orders SET type_of_order        = TRIM(type_of_order);
UPDATE zomato_orders SET type_of_vehicle      = TRIM(type_of_vehicle);
UPDATE zomato_orders SET city                 = TRIM(city);


-- now safe to convert these to real number types
ALTER TABLE zomato_orders
    MODIFY delivery_person_age      INT,
    MODIFY delivery_person_ratings  DECIMAL(3,1),
    MODIFY multiple_deliveries      INT;


-- Q1: how many NULLs ended up in each column after cleanup
-- (just checking how much data I'm actually going to lose in the
-- WHERE x IS NOT NULL queries later)
SELECT
    SUM(delivery_person_age     IS NULL) AS null_age,
    SUM(delivery_person_ratings IS NULL) AS null_ratings,
    SUM(time_orderd              IS NULL) AS null_time_orderd,
    SUM(weather_conditions       IS NULL) AS null_weather,
    SUM(road_traffic_density     IS NULL) AS null_traffic,
    SUM(multiple_deliveries      IS NULL) AS null_multiple_deliveries,
    SUM(festival                 IS NULL) AS null_festival,
    SUM(city                     IS NULL) AS null_city,
    COUNT(*)                             AS total_rows
FROM zomato_orders;


-- Q2: check for duplicate order ids
-- id is supposed to be unique per order, if this returns any rows
-- it means some orders got counted twice and every COUNT/AVG below
-- would be off
SELECT id, COUNT(*) AS occurrences
FROM zomato_orders
GROUP BY id
HAVING COUNT(*) > 1;


-- Q3: ratings should be between 1.0 and 5.0, anything outside that
-- is a bad entry, not a real rating
SELECT delivery_person_ratings, COUNT(*) AS occurrences
FROM zomato_orders
WHERE delivery_person_ratings IS NOT NULL
  AND (delivery_person_ratings < 1.0 OR delivery_person_ratings > 5.0)
GROUP BY delivery_person_ratings;


-- Q4: check for weird outlier delivery times using the IQR rule
-- (a 2 min delivery or a 300 min delivery is probably a logging
-- mistake, not a real order). not deleting anything here, just
-- pulling them up so I can eyeball what they look like
WITH bounds AS (
    SELECT
        p25.time_taken_min AS q1,
        p75.time_taken_min AS q3
    FROM
        (SELECT time_taken_min FROM zomato_orders ORDER BY time_taken_min
         LIMIT 1 OFFSET (SELECT FLOOR(COUNT(*) * 0.25) FROM zomato_orders)) AS p25,
        (SELECT time_taken_min FROM zomato_orders ORDER BY time_taken_min
         LIMIT 1 OFFSET (SELECT FLOOR(COUNT(*) * 0.75) FROM zomato_orders)) AS p75
)
SELECT
    z.id,
    z.time_taken_min,
    b.q1,
    b.q3,
    (b.q3 - b.q1)                          AS iqr,
    (b.q1 - 1.5 * (b.q3 - b.q1))           AS lower_fence,
    (b.q3 + 1.5 * (b.q3 - b.q1))           AS upper_fence
FROM zomato_orders z
CROSS JOIN bounds b
WHERE z.time_taken_min < (b.q1 - 1.5 * (b.q3 - b.q1))
   OR z.time_taken_min > (b.q3 + 1.5 * (b.q3 - b.q1));


-- Q5: make sure order_date actually parses as dd-mm-yyyy
-- if STR_TO_DATE can't parse a row it just returns NULL silently,
-- and that row would quietly disappear from any monthly trend
-- query without me noticing
SELECT id, order_date
FROM zomato_orders
WHERE order_date IS NOT NULL
  AND STR_TO_DATE(order_date, '%d-%m-%Y') IS NULL;
