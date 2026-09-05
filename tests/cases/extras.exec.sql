-- Run after extras.sql in the same session; the output is extras.exec.out.
EXECUTE add('first');
INSERT INTO item (name, price, tags, kinds, stock) VALUES ('second', 12.50, ARRAY['a', 'b'], ARRAY['A']::kind[], 3);
EXECUTE cheap(20);
EXECUTE no_kinds;
EXECUTE tagged('b');
EXECUTE stocked;
SELECT name, cardinality(tags) AS ntags, 'b' = ANY(tags) AS has_b, kinds, active, key IS NOT NULL AS keyed FROM item ORDER BY id;
\set ON_ERROR_STOP off
\set VERBOSITY terse
INSERT INTO item (name, tags, stock) VALUES ('bad', ARRAY[]::text[], -1);
UPDATE item SET active = true, price = 0 WHERE name = 'second';
SELECT 'still alive' AS after_error;
