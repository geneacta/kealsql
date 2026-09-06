DROP TRIGGER noop ON product;
DROP FUNCTION kealsql_trg_noop();
CREATE OR REPLACE FUNCTION shout(text) RETURNS text
    AS 'PGDIR/plkeal/stored_after/after.so', 'kealsql_shout' LANGUAGE C STRICT IMMUTABLE;
DROP FUNCTION twice(bigint);
CREATE OR REPLACE FUNCTION twice(bigint, bigint) RETURNS bigint
    AS 'PGDIR/plkeal/stored_after/after.so', 'kealsql_twice' LANGUAGE C STRICT IMMUTABLE;
CREATE OR REPLACE FUNCTION half(double precision) RETURNS double precision
    AS 'PGDIR/plkeal/stored_after/after.so', 'kealsql_half' LANGUAGE C STRICT IMMUTABLE;
CREATE OR REPLACE FUNCTION kealsql_trg_upper_sku() RETURNS trigger
    AS 'PGDIR/plkeal/stored_after/after.so', 'kealsql_trg_upper_sku' LANGUAGE C;
CREATE OR REPLACE TRIGGER upper_sku AFTER INSERT ON product
    FOR EACH ROW EXECUTE FUNCTION kealsql_trg_upper_sku();
