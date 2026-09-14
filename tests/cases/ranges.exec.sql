-- Run after ranges.sql in the same session; the output is ranges.exec.out.
INSERT INTO room (name) VALUES ('blue'), ('red');
EXECUTE book(1, 'ada', '2026-03-01', '2026-03-05');
EXECUTE book(1, 'bob', '2026-03-05', '2026-03-08');
EXECUTE book(2, 'cy', '2026-03-02', '2026-03-04');
EXECUTE booked_on('2026-03-03');
EXECUTE clashes(1, '2026-03-04', '2026-03-06');
EXECUTE bounds;
\set ON_ERROR_STOP off
\set VERBOSITY terse
EXECUTE book(1, 'dan', '2026-03-03', '2026-03-06');
\set ON_ERROR_STOP on
-- tariffs: a chain 1..7, 7..30 is fine; a gap or an overlap is refused at commit
BEGIN;
EXECUTE price(1, 7, 1, 9000);
EXECUTE price(1, 30, 7, 7000);
COMMIT;
EXECUTE tariff_for(1, 3);
EXECUTE tariff_for(1, 20);
EXECUTE tariff_for(1, 40);
\set ON_ERROR_STOP off
BEGIN;
EXECUTE price(1, 60, 31, 5000);
COMMIT;
BEGIN;
EXECUTE price(1, 45, 25, 5000);
COMMIT;
\set ON_ERROR_STOP on
SELECT count(*) AS tariffs FROM tariff;
-- an open-ended tariff, then another: the first is closed where the second starts
EXECUTE open(1, 30, 5000);
EXECUTE open(1, 45, 4000);
EXECUTE tariff_for(1, 40);
EXECUTE tariff_for(1, 50);
SELECT nights, cents FROM tariff WHERE room = 1 ORDER BY lower(nights);
-- an inclusive upper bound: [03-08, 03-09] touches bob's [03-05, 03-08)? no — but a stay ending 03-08 inclusive would
EXECUTE inclusive(1, '2026-03-08', '2026-03-09');
EXECUTE inclusive(1, '2026-03-07', '2026-03-09');
-- a chain rearranged inside one transaction is judged only at its end
BEGIN;
DELETE FROM tariff WHERE nights = int8range(7, 30);
EXECUTE price(1, 15, 7, 8000);
EXECUTE price(1, 30, 15, 6000);
COMMIT;
SELECT count(*) AS tariffs FROM tariff;
\set ON_ERROR_STOP off
BEGIN;
DELETE FROM tariff WHERE nights = int8range(15, 30);
COMMIT;
\set ON_ERROR_STOP on
SELECT count(*) AS tariffs FROM tariff;
