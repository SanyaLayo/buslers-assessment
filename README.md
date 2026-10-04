# buslers data pipeline assessment

## setup instructions
python -m venv .venv
.venv\scripts\activate
pip install -r requirements.txt
python src/pipeline.py

## assumptions
- reference time: the "today" of this dataset is strictly treated as `2025-06-15 07:00`.
- total bookings: counts all deduplicated booking attempts, regardless of final status.
- total revenue: sums the `amount` for bookings with status `completed` AND bookings with status `cancelled` where a fee (`amount` > 0) was still charged.
- invalid foreign keys: bookings with user_ids or trip_ids not found in the deduplicated reference tables are dropped.
- date window: forward bookings are legitimate, but anything outside the march 15 to june 20 window is excluded.
- duplicate resolution: when resolving duplicate booking_ids, the row with the most recent `updated_at` (or `created_at` if updated_at is null) is kept.

