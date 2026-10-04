# performance and troubleshooting

## 3a: why the original loop is slow
the original code uses `iterrows()`, which forces pandas to read the dataframe row by row, bypassing its underlying optimizations. for 241,000 rows, this means executing a manual python loop 241,000 times. it also performs a useless lookup (`df[df["trip_id"] == row["trip_id"]]`) on every single iteration, which makes it exponentially slower.

the rewritten vectorized version applies the condition to the entire column at once, reducing runtime from 8 minutes to a fraction of a second.

### rewritten code:
```python
import pandas as pd
import numpy as np
df = pd.read_csv("data/raw/bookings_raw.csv")
df["trip_revenue"] = np.where(df["booking_status"].str.lower().str.strip() == "completed", df["amount"] * 1.05, 0)
out = df[["booking_id", "user_id", "trip_revenue"]]

## 3b: scaling to 20m rows
at 20 million rows per day, loading a single csv into pandas will cause an out-of-memory failure.

parallelization: the vectorized revenue calculation can be fully parallelized because the rows do not depend on each other.

failure modes and solutions:
instead of going bigger (buying a massive server to hold 20m rows in memory), i would go smaller. i would partition the raw data by ingestion hour and process the chunks in parallel using a distributed engine like apache spark, or load the raw data directly into a warehouse and transform it using dbt.