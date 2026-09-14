ALTER TABLE room ADD COLUMN created timestamptz NOT NULL DEFAULT now();
ALTER TABLE tariff DROP CONSTRAINT tariff_room_nights_excl;
ALTER TABLE tariff ADD CONSTRAINT tariff_room_nights_key UNIQUE (room, nights WITHOUT OVERLAPS);
ALTER TABLE stay ADD CONSTRAINT stay_room_nights_fkey FOREIGN KEY (room, PERIOD nights) REFERENCES tariff (room, PERIOD nights);
