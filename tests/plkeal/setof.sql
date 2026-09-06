CREATE TABLE product (
    id serial PRIMARY KEY,
    sku text UNIQUE NOT NULL,
    price numeric(10, 2) NOT NULL,
    note text
);

CREATE OR REPLACE FUNCTION range(bigint) RETURNS SETOF bigint
    AS '$libdir/setof', 'kealsql_range' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION words(text) RETURNS SETOF text
    AS '$libdir/setof', 'kealsql_words' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION cheap(double precision) RETURNS SETOF product
    AS '$libdir/setof', 'kealsql_cheap' LANGUAGE C STRICT;

-- func cheaperThan(max: Decimal): List<Product>
PREPARE cheaper_than(numeric) AS
SELECT product.*
FROM product
WHERE product.price < $1
ORDER BY product.sku;
