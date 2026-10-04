-- 4.1: previous-month revenue by route
-- assumption: used created_at for the may 2025 boundary.
-- assumption: deduplicated bookings by keeping the most recent created_at per booking_id.
-- assumption: revenue includes completed trips. handled case-sensitivity in booking_status.
with deduped_bookings as (
select booking_id, trip_id, lower(booking_status) as status, amount, created_at,
row_number() over(partition by booking_id order by created_at desc) as rn
from bookings
where created_at >= '2025-05-01' and created_at < '2025-06-01'
)
select t.route_id,
sum(b.amount) as total_revenue,
count(b.booking_id) as completed_bookings
from deduped_bookings b
join trips t on b.trip_id = t.trip_id
where b.rn = 1 and b.status = 'completed'
group by t.route_id
order by total_revenue desc;

-- 4.2: repeat attempters who never complete
-- assumption: used created_at cast to date for the 30-day window (2025-05-16 to 2025-06-14).
-- assumption: deduplicated bookings before counting attempts and checking completions.
with deduped_bookings as (
select booking_id, user_id, lower(booking_status) as status,
row_number() over(partition by booking_id order by created_at desc) as rn
from bookings
where created_at::date >= '2025-05-16' and created_at::date <= '2025-06-14'
)
select user_id,
count(booking_id) as total_attempts
from deduped_bookings
where rn = 1
group by user_id
having count(booking_id) >= 3
and sum(case when status = 'completed' then 1 else 0 end) = 0;

-- 4.3: top 10 users by completed-booking revenue
-- guaranteed exactly one row per user by grouping strictly by user_id.
with deduped_bookings as (
select booking_id, user_id, amount, lower(booking_status) as status,
row_number() over(partition by booking_id order by created_at desc) as rn
from bookings
where created_at::date >= '2025-05-16' and created_at::date <= '2025-06-14'
)
select user_id,
sum(amount) as total_revenue
from deduped_bookings
where rn = 1 and status = 'completed'
group by user_id
order by total_revenue desc
limit 10;

-- 4.4: fix the warehouse
-- to prevent duplicates, i would add a unique constraint on booking_id.
-- before applying it, existing duplicates must be resolved by keeping the latest row (via row_number) and deleting the rest.
-- operational trade-offs:
-- 1. primary key: enforces uniqueness and not-null, creates a b-tree index. only one allowed per table. indicates the table's absolute grain.
-- 2. unique constraint: enforces uniqueness, creates a unique index. allows nulls unless explicitly forbidden. good for secondary candidate keys.
-- 3. plain index: speeds up lookups but does not enforce data integrity. allows duplicates to keep accumulating.
-- performance notes: i would add plain indexes on created_at (for date filtering) and user_id/trip_id (for joins).
-- i would use explain analyze to ensure the query planner is executing index scans rather than sequential scans on large date ranges.