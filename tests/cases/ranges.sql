CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE room (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL
);

CREATE TABLE booking (
    id serial PRIMARY KEY,
    room integer NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    guest text NOT NULL,
    stay daterange NOT NULL,
    CONSTRAINT booking_room_stay_excl EXCLUDE USING gist (room WITH =, stay WITH &&)
);

CREATE TABLE tariff (
    id serial PRIMARY KEY,
    room integer NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    nights int8range NOT NULL,
    cents integer NOT NULL,
    CONSTRAINT tariff_room_nights_excl EXCLUDE USING gist (room WITH =, nights WITH &&)
);
CREATE OR REPLACE FUNCTION kealsql_contiguous_tariff_room_nights_chain() RETURNS trigger LANGUAGE plpgsql AS $$-- kealsql_contiguous chain
BEGIN
    IF upper(NEW.nights) IS NULL THEN
        UPDATE tariff SET nights = int8range(lower(nights), lower(NEW.nights), '[)')
        WHERE room = NEW.room AND upper(nights) IS NULL AND lower(nights) < lower(NEW.nights);
    END IF;
    RETURN NEW;
END $$;
CREATE OR REPLACE TRIGGER kealsql_contiguous_tariff_room_nights_chain BEFORE INSERT ON tariff FOR EACH ROW EXECUTE FUNCTION kealsql_contiguous_tariff_room_nights_chain();
CREATE OR REPLACE FUNCTION kealsql_contiguous_tariff_room_nights() RETURNS trigger LANGUAGE plpgsql AS $$-- kealsql_contiguous
DECLARE broken bigint;
BEGIN
    SELECT count(*) INTO broken FROM (
        SELECT upper(t.nights) AS ends, lead(lower(t.nights)) OVER (PARTITION BY t.room ORDER BY lower(t.nights)) AS next_starts
        FROM tariff AS t
    ) AS chain WHERE next_starts IS NOT NULL AND (ends IS NULL OR next_starts <> ends);
    IF broken > 0 THEN RAISE EXCEPTION 'tariff: room, nights must be contiguous: a gap or an overlap between consecutive ranges' USING ERRCODE = 'integrity_constraint_violation'; END IF;
    RETURN NULL;
END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'kealsql_contiguous_tariff_room_nights' AND tgrelid = 'tariff'::regclass) THEN
    CREATE CONSTRAINT TRIGGER kealsql_contiguous_tariff_room_nights AFTER INSERT OR UPDATE OR DELETE ON tariff
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION kealsql_contiguous_tariff_room_nights();
END IF; END $$;

-- func bookedOn(day: Date): List<(String, String)>
PREPARE booked_on(date) AS
SELECT room.name, b.guest
FROM booking AS b
JOIN room ON b.room = room.id
WHERE b.stay @> $1
ORDER BY room.name, b.guest;

-- func clashes(room: Int, from: Date, to: Date): List<String>
PREPARE clashes(integer, date, date) AS
SELECT booking.guest
FROM booking
WHERE booking.room = $1 AND booking.stay && daterange($2, $3)
ORDER BY booking.guest;

-- func bounds(): List<(String, Date?, Date?)>
PREPARE bounds AS
SELECT booking.guest, lower(booking.stay), upper(booking.stay)
FROM booking
ORDER BY booking.guest;

-- func tariffFor(room: Int, night: Int): Int?
PREPARE tariff_for(integer, integer) AS
SELECT tariff.cents
FROM tariff
WHERE tariff.room = $1 AND tariff.nights @> ($2)::bigint
LIMIT 1;

-- proc book(room: Int, guest: String, from: Date, to: Date)
PREPARE book(integer, text, date, date) AS
INSERT INTO booking (room, guest, stay)
VALUES ($1, $2, daterange($3, $4));

-- proc price(room: Int, upTo: Int, fromNight: Int, cents: Int)
PREPARE price(integer, integer, integer, integer) AS
INSERT INTO tariff (room, nights, cents)
VALUES ($1, int8range($3, $2), $4);

-- proc open(room: Int, fromNight: Int, cents: Int)
PREPARE open(integer, integer, integer) AS
INSERT INTO tariff (room, nights, cents)
VALUES ($1, int8range($2, NULL), $3);

-- func inclusive(room: Int, from: Date, to: Date): List<String>
PREPARE inclusive(integer, date, date) AS
SELECT booking.guest
FROM booking
WHERE booking.room = $1 AND booking.stay && daterange($2, $3, '[]')
ORDER BY booking.guest;
