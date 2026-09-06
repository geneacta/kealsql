CREATE TABLE product (
    id serial PRIMARY KEY,
    sku text UNIQUE NOT NULL,
    price numeric(10, 2) NOT NULL,
    blob bytea
);

CREATE MATERIALIZED VIEW price_bands AS
    SELECT product.price > 50 AS dear, count(*) AS products
    FROM product
    GROUP BY product.price > 50;
COMMENT ON MATERIALIZED VIEW price_bands IS 'kealsql:647735221';

-- func bands(): List<(Bool, Int)>
PREPARE bands AS
SELECT b.dear, b.products
FROM price_bands AS b
ORDER BY b.dear;

-- proc refreshBands()
-- a utility statement, which PREPARE refuses: run it as it is
-- REFRESH MATERIALIZED VIEW price_bands;

-- proc stamp(sku: String, hex: String)
PREPARE stamp(text, text) AS
UPDATE product
SET blob = convert_to($2, 'UTF8')
WHERE product.sku = $1;

-- func blobs(): List<(String, Int?, String?, String?)>
PREPARE blobs AS
SELECT product.sku, octet_length(product.blob), encode(product.blob, 'hex'), convert_from(product.blob, 'UTF8')
FROM product
WHERE product.blob IS NOT NULL
ORDER BY product.sku;

-- func stamped(): List<String>
-- warning tests/cases/queries4.kealsql:31:30 this `==` can be `unknown`; rows where it is are dropped, and `===` treats null as a value
PREPARE stamped AS
SELECT product.sku
FROM product
WHERE product.blob = '\x6b65616c'::bytea;
