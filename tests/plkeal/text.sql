CREATE TABLE "user" (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL
);

CREATE OR REPLACE FUNCTION slugify(text) RETURNS text
    AS '$libdir/text', 'kealsql_slugify' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION fib(bigint) RETURNS bigint
    AS '$libdir/text', 'kealsql_fib' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION is_long(text, bigint) RETURNS boolean
    AS '$libdir/text', 'kealsql_is_long' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION halve(double precision) RETURNS double precision
    AS '$libdir/text', 'kealsql_halve' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION shout(text) RETURNS text
    AS '$libdir/text', 'kealsql_shout' LANGUAGE C STRICT;

-- func slugs(): List<(String, String)>
PREPARE slugs AS
SELECT "user".name, slugify("user".name)
FROM "user"
ORDER BY "user".name;

-- func longNames(min: Int): List<String>
PREPARE long_names(integer) AS
SELECT "user".name
FROM "user"
WHERE is_long("user".name, $1)
ORDER BY "user".name;
