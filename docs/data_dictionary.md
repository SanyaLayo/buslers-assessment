# Data dictionary

Everything below describes what the columns are *supposed* to mean. It does not
describe what is actually in the files, because a meaningful part of the
assessment is that the two do not agree. Where a column is known to be dirty in a
particular way, that is noted — but the full list of injected problems is yours
to discover.

All money is **NGN (Nigerian Naira)**. All timestamps are local Nigerian time
(WAT, UTC+1) unless a suffix says otherwise, and the SQL tables carry **no
timezone at all**.

---

## `data/raw/bookings_raw.csv` — 241,782 rows, 11 columns

The day-1 booking extract. One row is supposed to be one booking attempt. It is
not always one row, and it is not always one attempt.

| Column | Type (intended) | Description |
|---|---|---|
| `booking_id` | string, numeric-looking | Primary key of the booking. **Not unique in this file.** |
| `user_id` | int | FK → `users_export.user_id`. Also points at a "shadow" population of deleted/test/migrated accounts that the ops system still retains. |
| `trip_id` | int | FK → `trips_export.trip_id`. Can be recovered from `route_name` + `booking_date` when null. |
| `route_id` | int | FK → `route_master.route_id`. Occasionally disagrees with the trip's route. |
| `route_name` | string | Human-readable route label, e.g. `Lagos-Abuja`. Carries **casings, misspellings, abbreviations and extra whitespace** that all need normalising against `route_master.route_name_canonical`. |
| `booking_date` | date `YYYY-MM-DD` | Date of travel. The trip window is **2025-03-15 to 2025-06-20**, so forward bookings past `2025-06-15` are legitimate. |
| `booking_status` | enum | One of `COMPLETED`, `CANCELLED`, `PENDING`, `EXPIRED`, `NO_SHOW`, `REFUNDED`. **Casing, spacing and misspellings vary**, and there are values nobody recognises. |
| `amount` | decimal, 2dp | Fare charged in NGN. Contains nulls, non-numeric text, negatives, and legitimate zeros (complimentary / staff travel). A small number of very large values are pricing errors, not real fares. |
| `payment_status` | enum | One of `PAID`, `PENDING`, `FAILED`, `REFUNDED`, `PARTIAL`. Same casing and spelling problems as `booking_status`. |
| `created_at` | timestamp | When the booking was made. **Three different formats** are in the file, including ISO-8601 with a `Z`/offset suffix. The assessment "now" is `2025-06-15 07:00`. |
| `updated_at` | timestamp | When the row last changed. Same format problems, plus some nulls and a few rows where it precedes `created_at`. |

### Things worth knowing up front

- **Duplicates are not all the same kind.** Some rows are byte-identical
  re-sends. Some share a `booking_id` but differ in payload — that is an update
  arriving as a second row, and you have to keep the later one. The two cases
  need different handling.
- **`booking_date` past the extract date is not automatically an error.** Trips
  run to 2025-06-20 and the extract was taken 2025-06-15, so forward bookings
  are real. Separating those from genuinely impossible dates is part of the job.
- **A cancelled booking can still be worth money** — a cancellation fee is
  sometimes retained. `booking_status = CANCELLED` and `amount > 0` both occur,
  deliberately.
- **`route_name` is redundant with `route_id`**, which is what makes it useful:
  you can cross-check the two and detect which one is wrong on a given row.

---

## `data/raw/bookings_raw_day2_delta.csv` — 21,046 rows, same 11 columns

The next morning's load. Two kinds of row:

1. **New bookings** created after the day-1 cut, for trips from 2025-06-15
   onward.
2. **Re-sends** of `booking_id`s that already arrived in day 1, carrying a later
   `updated_at` and often a different `booking_status`.

Roughly 4,971 booking IDs overlap between the two files. This is the point of the
file: an append-only load will double-count, and a "keep whichever row you saw
last" merge will keep the stale version. You need both a key and an ordering.

Columns are dirty in exactly the same ways as day 1, at the same rates.

---

## `data/raw/bookings_raw_sample_1k.csv` — 1,000 rows

The first 1,000 rows of the day-1 extract, same columns. **Shuffled but not
cleaned** — it contains the same problems, just fewer of them. Use it to iterate
quickly; do not draw conclusions from it.

---

## `data/reference/route_master.csv` — 60 rows

| Column | Description |
|---|---|
| `route_id` | Integer key, `1`–`60`. |
| `route_name_canonical` | The correct spelling, e.g. `Lagos-Abuja`. This is your normalisation target. |
| `origin` | Departure city. |
| `destination` | Arrival city. |
| `distance_km` | Route length. |
| `fare_tier` | `SHORT`, `MEDIUM` or `LONG`. |

This file is clean.

---

## `data/reference/users_export.csv` — 25,125 rows

| Column | Description |
|---|---|
| `user_id` | Integer key, starting at `100001`. |
| `full_name` | Display name. Not unique, not normalised, occasionally blank. |
| `signup_date` | Date the account was created. Some nulls. |
| `corporate_id` | FK to a corporate account, or null for consumer signups. |
| `home_city` | Free text city. |
| `status` | `ACTIVE`, `SUSPENDED`, `DELETED`, or variants. |

Contains **duplicate `user_id`s** from an export that appended rather than
upserted. Treat the master as "one row per user after you resolve them", not as
a clean key.

---

## `data/reference/trips_export.csv` — 121,660 rows

| Column | Description |
|---|---|
| `trip_id` | Integer key. |
| `route_id` | FK → `route_master.route_id`. |
| `trip_date` | Date of travel. |
| `departure_time` | `HH:MM` local. |
| `capacity` | Seats on the bus. |
| `bus_id` | Vehicle identifier. |

The trip table is **not clean either**: duplicated `trip_id`s, a handful of rows
where `route_id` and `trip_date` disagree with the rest of the table, and some
nulls. It is the more realistic of the two reference files, and validating
against it is harder because you have to normalise it first.

---

## `data/sql_seed/` — PART 4

### `schema.sql`

```sql
users     (user_id PK, signup_date, corporate_id)
trips     (trip_id PK, route_id, trip_date, capacity)
bookings  (booking_id, user_id, trip_id, booking_status, amount, created_at)
```

`users` and `trips` have primary keys. **`bookings` has no primary key, no unique
constraint and no indexes at all.** That is the production problem PART 4 asks
you to fix, so do not "fix" it before you have answered Task 4.

### `users.csv` — 25,000 rows
Clean subset of the user master: `user_id`, `signup_date`, `corporate_id`.

### `trips.csv` — 120,000 rows
Clean subset of the trip dimension: `trip_id`, `route_id`, `trip_date`, `capacity`.

### `bookings.csv` — 292,471 rows

| Column | Description |
|---|---|
| `booking_id` | **Not unique.** Repeated for the several different reasons below. |
| `user_id` | Not fully foreign-key-valid; some users are missing from `users`. |
| `trip_id` | Already inner-joined against `trips`, so orphans are gone — which quietly loses rows you may still want to count. |
| `booking_status` | `VARCHAR(20)`, free text. A `WHERE booking_status = 'COMPLETED'` filter silently drops rows that are `completed`, `Completed`, `COMPELTED`, `DONE`, `TRUE`, `0`. |
| `amount` | `NUMERIC(12,2)`. Unparseable values landed as `0`. Some rows were double-charged. |
| `created_at` | `TIMESTAMP`, **no timezone.** Some values are null; some are after the extract time. |

A naive `SELECT SUM(amount) FROM bookings WHERE booking_status = 'COMPLETED'`
returns roughly **15% more than Finance's number**, from six distinct causes. We
know what each one is. Part of PART 4 is finding them and quantifying them, so
work it out from the data rather than guessing.

---

## Assessment calendar

| Anchor | Date |
|---|---|
| Extract taken | `2025-06-15 07:00` |
| Day-1 load | `2025-06-14` |
| Day-2 load | `2025-06-15` (partial) |
| Trip window | `2025-03-15` → `2025-06-20` |
| "Previous month" (Task 4.1) | May `2025` |
| "Last 30 days" (Tasks 4.2, 4.3) | `2025-05-16` → `2025-06-14` |
