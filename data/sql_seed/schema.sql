-- Buslers analytics warehouse - assessment seed schema
--
-- Note what is missing. `bookings` has no primary key and no unique constraint
-- on booking_id, and there are no secondary indexes. That mirrors the
-- production table PART 4 / Task 4 is about.
--
-- Load with:
--   psql -d buslers -f schema.sql
--   \copy bookings FROM 'data/sql_seed/bookings.csv' CSV HEADER

DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    user_id      BIGINT       PRIMARY KEY,
    signup_date  DATE         NOT NULL,
    corporate_id INT          NULL
);

CREATE TABLE trips (
    trip_id   BIGINT PRIMARY KEY,
    route_id  INT    NOT NULL,
    trip_date DATE   NOT NULL,
    capacity  INT    NOT NULL
);

CREATE TABLE bookings (
    booking_id     BIGINT        NULL,
    user_id        BIGINT        NULL,
    trip_id        BIGINT        NULL,
    booking_status VARCHAR(20)   NULL,
    amount         NUMERIC(12,2) NULL,
    created_at     TIMESTAMP     NULL
);
