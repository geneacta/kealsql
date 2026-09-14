CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE room (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL,
    created timestamptz NOT NULL DEFAULT now(),
    note text
);

CREATE TABLE tariff (
    id serial PRIMARY KEY,
    room integer NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    nights int8range NOT NULL,
    cents integer NOT NULL,
    created timestamptz NOT NULL DEFAULT now(),
    note text,
    CONSTRAINT tariff_room_nights_key UNIQUE (room, nights WITHOUT OVERLAPS)
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

CREATE TABLE stay (
    id serial PRIMARY KEY,
    room integer NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    guest text NOT NULL,
    nights int8range NOT NULL,
    FOREIGN KEY (room, PERIOD nights) REFERENCES tariff (room, PERIOD nights)
);

-- func noted(): List<(String, String?)>
PREPARE noted AS
SELECT room.name, room.note
FROM room
ORDER BY room.name;

-- func stays(room: Int): List<(String, Int?, Int?)>
PREPARE stays(integer) AS
SELECT stay.guest, lower(stay.nights), upper(stay.nights)
FROM stay
WHERE stay.room = $1
ORDER BY stay.guest;

-- proc price(room: Int, upTo: Int, fromNight: Int, cents: Int)
PREPARE price(integer, integer, integer, integer) AS
INSERT INTO tariff (room, nights, cents)
VALUES ($1, int8range($3, $2), $4);

-- proc book(room: Int, guest: String, from: Int, to: Int)
PREPARE book(integer, text, integer, integer) AS
INSERT INTO stay (room, guest, nights)
VALUES ($1, $2, int8range($3, $4));
