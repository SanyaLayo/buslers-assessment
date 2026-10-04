import pandas as pd
import numpy as np

def load_csv(path): return pd.read_csv(path)

def merge_incremental(df1, df2): return pd.concat([df1, df2]).assign(key=lambda x: pd.to_datetime(x['updated_at'], format='mixed', errors='coerce', utc=True).fillna(pd.to_datetime(x['created_at'], format='mixed', errors='coerce', utc=True))).sort_values('key', ascending=False).drop_duplicates(subset='booking_id')

def clean_bookings(df, users, trips): df['booking_status'] = df['booking_status'].str.lower().str.strip(); df['amount'] = pd.to_numeric(df['amount'], errors='coerce'); df['amount'] = np.where(df['amount'] < 0, np.nan, df['amount']); df['booking_date_dt'] = pd.to_datetime(df['booking_date'], format='mixed', errors='coerce'); df = df[(df['booking_date_dt'] >= '2025-03-15') & (df['booking_date_dt'] <= '2025-06-20')]; df = df[df['user_id'].isin(users['user_id']) & df['trip_id'].isin(trips['trip_id'])]; return df

def aggregate_metrics(df): df['is_completed'] = np.where(df['booking_status'] == 'completed', 1, 0); df['is_cancelled'] = np.where(df['booking_status'] == 'cancelled', 1, 0); df['rev'] = np.where((df['booking_status'] == 'completed') | ((df['booking_status'] == 'cancelled') & (df['amount'] > 0)), df['amount'], 0); agg = df.groupby(['booking_date', 'route_id']).agg(total_bookings=('booking_id', 'count'), completed_bookings=('is_completed', 'sum'), cancelled_bookings=('is_cancelled', 'sum'), total_revenue=('rev', 'sum'), unique_users=('user_id', 'nunique')).reset_index(); agg['average_booking_value'] = np.where(agg['total_bookings'] > 0, agg['total_revenue'] / agg['total_bookings'], 0); return agg

def run_all(): df1 = load_csv('data/raw/bookings_raw.csv'); df2 = load_csv('data/raw/bookings_raw_day2_delta.csv'); users = load_csv('data/reference/users_export.csv').drop_duplicates('user_id'); trips = load_csv('data/reference/trips_export.csv').drop_duplicates('trip_id'); merged = merge_incremental(df1, df2); cleaned = clean_bookings(merged, users, trips); agg = aggregate_metrics(cleaned); agg.to_csv('daily_reporting_dataset.csv', index=False); print('pipeline complete')

if __name__ == '__main__': run_all()