-- Run after temporal.sql in the same session; the output is temporal.exec.out.
INSERT INTO room (name, note) VALUES ('blue', 'sea view'), ('red', NULL);
EXECUTE noted;
EXECUTE price(1, 10, 1, 9000);
EXECUTE price(1, 20, 10, 7000);
EXECUTE book(1, 'ada', 3, 15);
EXECUTE stays(1);
\set ON_ERROR_STOP off
\set VERBOSITY terse
EXECUTE book(1, 'bob', 15, 25);
EXECUTE book(2, 'cy', 1, 2);
\set ON_ERROR_STOP on
EXECUTE stays(1);
SELECT count(*) FILTER (WHERE created IS NOT NULL) AS audited FROM tariff;
