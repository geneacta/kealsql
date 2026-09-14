CREATE EXTENSION IF NOT EXISTS btree_gist;
-- DESTRUCTIVE, held back (pass --destructive to emit it): fails if two rows of `booking` already overlap
-- ALTER TABLE booking ADD CONSTRAINT booking_room_stay_excl EXCLUDE USING gist (room WITH =, stay WITH &&);
CREATE OR REPLACE FUNCTION kealsql_contiguous_booking_room_stay_chain() RETURNS trigger LANGUAGE plpgsql AS $$-- kealsql_contiguous chain
BEGIN
    IF upper(NEW.stay) IS NULL THEN
        UPDATE booking SET stay = daterange(lower(stay), lower(NEW.stay), '[)')
        WHERE room = NEW.room AND upper(stay) IS NULL AND lower(stay) < lower(NEW.stay);
    END IF;
    RETURN NEW;
END $$;
CREATE OR REPLACE TRIGGER kealsql_contiguous_booking_room_stay_chain BEFORE INSERT ON booking FOR EACH ROW EXECUTE FUNCTION kealsql_contiguous_booking_room_stay_chain();
CREATE OR REPLACE FUNCTION kealsql_contiguous_booking_room_stay() RETURNS trigger LANGUAGE plpgsql AS $$-- kealsql_contiguous
DECLARE broken bigint;
BEGIN
    SELECT count(*) INTO broken FROM (
        SELECT upper(t.stay) AS ends, lead(lower(t.stay)) OVER (PARTITION BY t.room ORDER BY lower(t.stay)) AS next_starts
        FROM booking AS t
    ) AS chain WHERE next_starts IS NOT NULL AND (ends IS NULL OR next_starts <> ends);
    IF broken > 0 THEN RAISE EXCEPTION 'booking: room, stay must be contiguous: a gap or an overlap between consecutive ranges' USING ERRCODE = 'integrity_constraint_violation'; END IF;
    RETURN NULL;
END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'kealsql_contiguous_booking_room_stay' AND tgrelid = 'booking'::regclass) THEN
    CREATE CONSTRAINT TRIGGER kealsql_contiguous_booking_room_stay AFTER INSERT OR UPDATE OR DELETE ON booking
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION kealsql_contiguous_booking_room_stay();
END IF; END $$;
-- 1 statement held back
