# data pipeline architecture

## component flow
1. ingestion: web, mobile, and call centre apps stream booking events into a message broker (e.g., apache kafka) to handle traffic spikes safely.
2. raw storage (data lake): events land in an object store (s3/gcs) as raw json/csv files, partitioned by date (`/raw/yyyy/mm/dd/`).
3. orchestration & processing: a daily job triggered by airflow reads the raw files. we use apache spark for distributed processing to handle the 20m row volume without memory errors.
4. serving layer: cleaned, deduplicated data is written in columnar format (parquet) and loaded into a warehouse for bi tools.

## incremental strategy (day 2 delta)
to avoid double-counting revenue while keeping the latest status:
- merge key: `booking_id`
- ordering key: `updated_at` (descending), falling back to `created_at`
- logic: union the historical data with the new delta file, partition by `booking_id`, sort by the ordering key, and keep only the first row.