# Data Analyst Assessment — Buslers (Analytics & Data Infrastructure)

**Role:** Data Analyst, Analytics & Data Infrastructure
**Timebox:** 4–6 hours
**Reference date for all questions:** `2025-06-15 07:00`

You are joining a small data team at Buslers, a Nigerian intercity transport
operator. We collect booking events from a web app, an Android app, and a small
call-centre script, and we land them in a Postgres warehouse every morning. The
data engineering team is out of capacity, so reporting is temporarily on you.

Everything you need is in this repository. Read `docs/data_dictionary.md` first,
then `docs/open_questions.md`.

---

## PART 1 — Data pipeline architecture

**1A.** Our booking data lands in three ways (web, mobile, call centre), then
lands daily in Postgres. Draw the architecture you would use for
`data/raw/bookings_raw.csv` → the daily reporting dataset in PART 2.

Your diagram must cover: ingestion, storage (raw vs clean), orchestration, and
the serving layer. Assume the raw feed grows to **20 million rows per day**
within 18 months and that at least a handful of people need to be querying it
ad hoc. Include a component diagram and explain your choices — file format,
partitioning, incremental strategy, and where the expensive work happens.

**1B.** You already have today's load (`bookings_raw.csv`) and the next day's
load (`bookings_raw_day2_delta.csv`). The delta is **not** a clean "new rows
only" file: it re-sends `booking_id`s that already arrived in day 1, sometimes
with a later `updated_at` and a different status.

Describe the incremental strategy you would use so that re-sending a row never
double-counts revenue and a genuine status change always wins. Be specific about
merge keys, ordering, and what you do when two rows disagree.

**Deliverables:** `docs/architecture.png` (or an export of your diagram tool),
and a short write-up. A small working prototype of the incremental merge is
welcome in `src/pipeline.py` — it does not have to be production code, but it
should run on the data in this repository.

---

## PART 2 — Load, profile, clean, aggregate

**2A.** Load `data/raw/bookings_raw.csv`. The file is **241,782 rows** and it is
**not clean**. Produce a data quality profile *before* you change anything:
row count, column types, null counts, distinct counts, and at minimum: duplicate
detection, referential integrity against `users_export.csv` and
`trips_export.csv`, and any impossible or out-of-range values.

**2B.** Clean it. There is a lot to fix, and you will not catch everything —
that is fine. What matters is that you fix things **deliberately**:

- Normalise `route_name` against `route_master.csv`. The same route appears
  under several spellings; pick a method (fuzzy matching, mapping table, or
  something else) and justify it.
- Resolve `booking_id` duplicates. Some are true duplicate submissions, some
  are later updates to the same booking. Your rule should be stated, not
  implicit.
- Handle nulls, non-numeric values, and outliers in `amount`.
- Validate `trip_id`, `user_id`, and `route_id` against the reference tables.
  Decide what to do with rows that fail.

**2C.** Aggregate to the daily reporting dataset:

```
booking_date, route_id, total_bookings, completed_bookings,
cancelled_bookings, total_revenue, average_booking_value, unique_users
```

Grouped by `booking_date` and `route_id`. Define `total_revenue` and
`total_bookings` in your README — there is more than one defensible answer, and
we want to see which one you chose and why. Consider whether cancelled bookings
count toward `total_bookings`, whether unpaid completed bookings count toward
revenue, and what happens to rows you could not clean.

**Deliverables:** `src/pipeline.py` (functions, not one long script), a profile
report, the cleaned/aggregated output, and a written summary of the issues you
found with your chosen fixes.

---

## PART 3 — Performance and troubleshooting

**3A.** A colleague left you this:

```python
import pandas as pd

df = pd.read_csv("bookings_raw.csv")
results = []

for i, row in df.iterrows():
    trip = df[df["trip_id"] == row["trip_id"]]
    if row["booking_status"] == "COMPLETED":
        revenue = row["amount"] * 1.05      # fx uplift
    else:
        revenue = 0
    results.append({
        "booking_id": row["booking_id"],
        "user_id": row["user_id"],
        "trip_revenue": revenue,
    })

out = pd.DataFrame(results)
```

On our 241k-row file this runs for roughly **8 minutes** and will not survive
contact with 20M rows. Explain, in a way a non-technical stakeholder would
follow, what is actually slow and why. Then rewrite it. Show the before/after
timing and explain the complexity of the original.

**3B.** Discuss: which parts of the new version can be parallelised, and what
are the realistic failure modes at 20M rows/day? Specifically — where would you
hit memory limits, and what would you do about it? Do you go bigger (bigger
machines, more partitions) or smaller (more, smaller steps)? Defend your answer.

**Deliverables:** `docs/performance_notes.md`, and the rewritten code.

---

## PART 4 — SQL

Load `data/sql_seed/` into Postgres:

```bash
psql -d buslers -f data/sql_seed/schema.sql
psql -d buslers -c "\copy users FROM 'data/sql_seed/users.csv' CSV HEADER"
psql -d buslers -c "\copy trips FROM 'data/sql_seed/trips.csv' CSV HEADER"
psql -d buslers -c "\copy bookings FROM 'data/sql_seed/bookings.csv' CSV HEADER"
```

`bookings` is a **badly loaded copy of the extract**: the load job replayed
files, re-sent updates as new rows, and some rows were relabelled. It contains
**292,471 rows** across 6 columns and it has **no primary key**. The timestamps
have **no timezone**.

**4.1 — Previous-month revenue by route.** For May 2025, report total revenue
and completed bookings per route, best first. Note in your comments how you
treated the timestamp boundary and whether you deduplicated.

**4.2 — Repeat attempters who never complete.** Find users who have **attempted
to book at least 3 times in the last 30 days** (2025-05-16 to 2025-06-14) but
have **never completed** a single booking. This is our churn-risk list. Explain
which timestamp you used and why, and how you handled the duplicate rows.

**4.3 — Top users.** Top 10 users by completed-booking revenue, for the same
window. The leaderboard must have **exactly one row per user** — if it does not,
your query is wrong. Explain how you guaranteed that.

**4.4 — Fix the warehouse.** Propose the constraint or index that would prevent
this table from accumulating duplicate `booking_id`s, say what you would do
about the rows already duplicated, and describe the operational trade-off
between a unique constraint, a primary key, and a plain index. Do not just say
"add a primary key".

**Deliverables:** `sql/analysis.sql` with your four queries, commented, plus a
short note on performance (what indexes you would add, and what you would check
with `EXPLAIN ANALYZE`).

---

## PART 5 — Repository and communication

Push this to a **public or private** GitHub repository you own and share the URL.

- Work on a **feature branch**, and merge it into `main` with a real merge commit.
- A README that lets a reviewer who has never met you run the project in under
  five minutes, including: how to run it, the environment, and your assumptions.
- Commits that tell a story. A reviewer should be able to read your commit
  messages and understand your reasoning.
- Tests. At least a few. They should assert real behaviour, including at least
  one case where your pipeline is expected to **fail** (bad input) rather than
  silently pass.

**Deliverables:** the repository URL, and a short summary message (DM or email)
to your hypothetical manager. One paragraph: what you found, what you fixed,
what you would do next, and what you need from Engineering.

---

## How you will be assessed

| Area | What we are looking for |
|---|---|
| **Approach** | You read and profile the data before writing the solution. Findings drive the design. |
| **Assumptions** | Ambiguity is named out loud, a default is chosen, the impact is stated. |
| **Correctness** | Aggregates reconcile, counts add up, edge cases handled rather than ignored. |
| **Efficiency** | No `iterrows` over anything large. The 241k run completes in seconds, not minutes. |
| **Validation** | Checks that would actually fail the pipeline — not checks that always pass. |
| **SQL** | Correct results, and an explanation of why the query plan is acceptable. |
| **Troubleshooting** | When something looks wrong, the first move is to measure, not to guess. |
| **Git** | Clean history, a real branch, a real merge, a usable README. |
| **Communication** | A reviewer can run this and trust it without asking you anything. |

Things that will count against you: dropping rows without saying so, filling
nulls with zero, catching bare `Exception`, a pipeline that only runs top to
bottom, a README with no assumptions section, and a leaderboard where one user
appears four times.

If you run out of time, submit what you have with a clear note on what is
unfinished. Writing down what you would do next is worth more than silence.
