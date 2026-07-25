-- Part: 1 - schema
-- Project - Zomato Delivery Operations Analytics
-- Author: Rishav Raj
-- Dataset: Zomato_Dataset.csv (45,584 rows)
-- MySQL 8 (uses window functions + STR_TO_DATE later on)
--
-- This is just the table setup, nothing gets cleaned or grouped here yet,
-- that's all in 02_data_cleaning.sql.
--
-- Stuff to know before reading the rest of this project:
-- - there's no "zone" column in the data, so wherever I need "top zones"
--   I just used City, it's the closest thing available
-- - order types are Snack / Meal / Drinks / Buffet, no Grocery category,
--   so "food vs grocery" turned into a comparison across these 4 instead
-- - weather doesn't have "Rainy", closest is "Stormy", used that for rain
-- - missing values in the csv aren't blank, they're literally the text
--   "NaN". if you load age/ratings/multiple_deliveries straight into
--   number columns MySQL turns "NaN" into 0 without warning, which
--   wrecks every average (a driver with no rating suddenly becomes a
--   0-star driver). so those 3 columns are loaded as text first and
--   only converted after cleanup in the next file.

DROP TABLE IF EXISTS zomato_orders;

CREATE TABLE zomato_orders (
    id                              VARCHAR(10),
    delivery_person_id              VARCHAR(30),
    delivery_person_age             VARCHAR(10),   -- text for now, has 'NaN' junk
    delivery_person_ratings         VARCHAR(10),   -- text for now, has 'NaN' junk
    restaurant_latitude              DECIMAL(10,6),
    restaurant_longitude             DECIMAL(10,6),
    delivery_location_latitude       DECIMAL(10,6),
    delivery_location_longitude      DECIMAL(10,6),
    order_date                       VARCHAR(12),   -- comes in as dd-mm-yyyy text
    time_orderd                      VARCHAR(10),   -- has 'NaN' junk too
    time_order_picked                VARCHAR(8),
    weather_conditions               VARCHAR(20),   -- has 'NaN' junk
    road_traffic_density             VARCHAR(20),   -- has 'NaN' junk
    vehicle_condition                INT,
    type_of_order                    VARCHAR(20),
    type_of_vehicle                  VARCHAR(30),
    multiple_deliveries              VARCHAR(5),    -- text for now, has 'NaN' junk
    festival                         VARCHAR(5),    -- has 'NaN' junk
    city                             VARCHAR(20),   -- has 'NaN' junk
    time_taken_min                   INT
);

-- LOAD DATA LOCAL INFILE 'Zomato_Dataset.csv'
-- INTO TABLE zomato_orders
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

-- added these indexes after noticing the queries in the other files keep
-- grouping/filtering on the same columns over and over, made things faster
CREATE INDEX idx_delivery_person_id   ON zomato_orders (delivery_person_id);
CREATE INDEX idx_city                 ON zomato_orders (city);
CREATE INDEX idx_order_date           ON zomato_orders (order_date);
CREATE INDEX idx_weather_conditions   ON zomato_orders (weather_conditions);
CREATE INDEX idx_road_traffic_density ON zomato_orders (road_traffic_density);
CREATE INDEX idx_type_of_vehicle      ON zomato_orders (type_of_vehicle);
CREATE INDEX idx_festival             ON zomato_orders (festival);
