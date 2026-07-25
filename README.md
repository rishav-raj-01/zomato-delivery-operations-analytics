# Zomato Delivery Operations Analytics

A SQL and Python project where I dug into a Zomato delivery dataset to figure out what actually slows deliveries down, weather, traffic, city type, festivals, or something else entirely.

Dataset: [Zomato Delivery Operations Analytics Dataset](https://www.kaggle.com/datasets/saurabhbadole/zomato-delivery-operations-analytics-dataset) on Kaggle, 45,584 rows.

## Why I did this

I wanted a project that wasn't just "load CSV, make a chart, done." Delivery data has a lot of small, annoying real-world problems in it, missing values that aren't actually blank, dates in a weird format, ratings that don't make sense, and I wanted practice cleaning that properly in SQL before touching any of the analysis. Once the data was clean, I used it to answer questions I'd actually want answered if I ran a delivery operation: which city is the slowest, does bad weather actually cost real minutes, are festival days as bad as everyone assumes.

## What's in this repo

```
01_schema.sql                        table setup, column types, indexes
02_data_cleaning.sql                 turning "NaN" text into real NULLs, type conversion, sanity checks
03_eda_queries.sql                   basic exploration, one metric at a time (Q1-Q36)
04_delivery_operations_analysis.sql  CTEs and window functions, deeper analysis (Q37-Q49)
zomato_eda.ipynb                     same kind of exploration but in Python, with charts
Zomato_Dataset.csv                   the raw data
```

The SQL files are numbered so I could run them in order and so I can reference specific queries later without having to explain the whole thing again.

## How to run it

1. Set up MySQL 8 (needed for the window functions in file 04).
2. Run `01_schema.sql` to create the table.
3. Load the CSV into the table (there's a commented out `LOAD DATA LOCAL INFILE` block in the schema file, just uncomment it and point it at your local path).
4. Run `02_data_cleaning.sql`.
5. Run `03_eda_queries.sql` and `04_delivery_operations_analysis.sql` in any order after that.

For the Python side, `zomato_eda.ipynb` just needs pandas, matplotlib, and seaborn, and expects the CSV in a `data/` folder next to it.

## Cleaning notes (the annoying part)

A few things about this dataset that aren't obvious until you actually try to load it:

- Missing values in the CSV are the literal text `"NaN"`, not an actual blank cell. If you load age, ratings, or multiple_deliveries straight into number columns, MySQL silently turns `"NaN"` into `0`, which quietly wrecks every average (a driver with no rating on file suddenly looks like a 0-star driver). So those three columns get loaded as text first and only converted to numbers after the NaN cleanup.
- There's no zone column, so anywhere I needed something like "top zones," I used City instead, it's the closest thing available (Urban, Metropolitan, Semi-Urban).
- There's no rain category in the weather column, the closest match is "Stormy," so that's what I used for rain-related questions.
- Some of the latitude and longitude values are broken, a handful come out negative when they shouldn't (well outside India), which looks like a sign error in the source data rather than real GPS drift. I didn't try to fix these since I wasn't using coordinates for distance calculations, but it's worth knowing about if you extend this project.

## What I found

- **Semi-Urban orders take about twice as long as Urban ones.** Semi-Urban averages 49.7 minutes, Urban averages 23.0 minutes. That gap is way bigger than I expected going in.
- **Fog combined with jammed traffic is the worst condition pairing in the whole dataset**, averaging 36.8 minutes, compared to 21.5 minutes for the best case (low traffic, sunny weather). Neither fog nor traffic alone is anywhere near this bad on its own, it's the combination that does the damage.
- **Festival days add close to 75% to delivery time** (45.5 minutes vs 26.0 minutes on a normal day). This lines up with what you'd expect, more orders hitting the same number of drivers, but it was still bigger than I guessed before running the numbers.
- Driver age doesn't show any real pattern against delivery speed. Rating and speed also aren't strongly linked, a highly rated driver isn't necessarily a fast one, which made me think ratings are probably measuring something else entirely, like order accuracy or politeness, not speed.
- Splitting drivers into speed quartiles (fastest 25% to slowest 25%) shows a real, consistent gap between the top and bottom group, so speed differences aren't just noise, some drivers are consistently faster than others even after accounting for city and traffic.

## Tools

MySQL 8, Python (pandas, matplotlib, seaborn), Jupyter Notebook

## Author

Rishav Raj
