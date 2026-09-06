CREATE TYPE kind AS ENUM ('Book', 'Disc');

CREATE TABLE product (
    id serial PRIMARY KEY,
    sku text UNIQUE NOT NULL,
    title text NOT NULL,
    kind kind NOT NULL,
    price numeric(10, 2) NOT NULL,
    stock integer NOT NULL DEFAULT 0,
    released date,
    tags text[] NOT NULL DEFAULT ARRAY[]::text[]
);

CREATE TABLE sale (
    id serial PRIMARY KEY,
    product integer NOT NULL REFERENCES product(id) ON DELETE CASCADE,
    sold_at timestamptz NOT NULL DEFAULT now(),
    units integer NOT NULL
);

-- proc seed()
PREPARE seed AS
INSERT INTO product (sku, title, kind, price)
VALUES ('B-1', 'Dune', 'Book', 9.9),
       ('B-2', 'Solaris', 'Book', 8.5),
       ('D-1', 'Kind of Blue', 'Disc', 14.0);

-- proc restock(sku: String, title: String, kind: Kind, price: Decimal, units: Int)
PREPARE restock(text, text, kind, numeric, integer) AS
INSERT INTO product (sku, title, kind, price, stock)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (sku) DO UPDATE SET stock = product.stock + EXCLUDED.stock, price = EXCLUDED.price;

-- proc register(sku: String, title: String, kind: Kind, price: Decimal)
PREPARE register(text, text, kind, numeric) AS
INSERT INTO product (sku, title, kind, price)
VALUES ($1, $2, $3, $4)
ON CONFLICT (sku) DO NOTHING;

-- func rankedByPrice(): List<(String, Kind, Int)>
PREPARE ranked_by_price AS
SELECT product.title, product.kind, rank() OVER (PARTITION BY product.kind ORDER BY product.price DESC)
FROM product
ORDER BY product.kind, product.price DESC;

-- func runningStock(): List<(String, Int, Int?)>
PREPARE running_stock AS
SELECT product.sku, COALESCE(sum(product.stock) OVER (ORDER BY product.sku), 0), lag(product.stock) OVER (ORDER BY product.sku)
FROM product
ORDER BY product.sku;

-- func cheapOrDisc(): List<(String, String)>
PREPARE cheap_or_disc AS
SELECT product.sku, product.title
FROM product
WHERE product.price < 9
UNION (SELECT product.sku, product.title FROM product WHERE product.kind = 'Disc');

-- func booksNotCheap(): List<String>
PREPARE books_not_cheap AS
SELECT product.sku
FROM product
WHERE product.kind = 'Book'
EXCEPT (SELECT product.sku FROM product WHERE product.price < 9);

-- func shouted(): List<(String, String, Int, Bool)>
PREPARE shouted AS
SELECT replace(product.sku, '-', ''), substr(upper(product.title), 1, 3), position('o' in product.title), product.sku ~ '^B-[0-9]+$'
FROM product
ORDER BY product.sku;

-- func padded(): List<(String, String)>
PREPARE padded AS
SELECT lpad(product.sku, 6, '0'), CAST(product.price AS text) || ' EUR'
FROM product
ORDER BY product.sku;

-- func releaseYears(): List<(String, Int?, Date?)>
PREPARE release_years AS
SELECT product.sku, CAST(EXTRACT(YEAR FROM product.released) AS integer), product.released + 30
FROM product
ORDER BY product.sku;

-- func summary(): List<(Kind, Int, String?, Decimal?)>
PREPARE summary AS
SELECT product.kind, count(DISTINCT product.price), string_agg(product.sku, ',' ORDER BY product.sku), max(product.price)
FROM product
GROUP BY product.kind
ORDER BY product.kind;

-- func flags(): (Bool?, Bool?)
PREPARE flags AS
SELECT bool_and(product.stock >= 0), bool_or(product.price > 100)
FROM product
LIMIT 2;

-- func allTags(): List<String>?
PREPARE all_tags AS
SELECT array_agg(product.sku ORDER BY product.sku DESC)
FROM product
LIMIT 2;

-- func nextToShip(): List<String>
PREPARE next_to_ship AS
SELECT product.sku
FROM product
WHERE product.stock > 0
ORDER BY product.sku
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- func crossed(): Int
PREPARE crossed AS
SELECT count(*)
FROM product AS a
CROSS JOIN product AS b
WHERE a.id < b.id;

-- func withSales(): List<(String?, Int?)>
PREPARE with_sales AS
SELECT p.sku, s.units
FROM product AS p
FULL JOIN sale AS s ON s.product = p.id
ORDER BY p.sku NULLS LAST;

-- func titlesLike(pattern: String): List<(Int, String)>
PREPARE titles_like(text) AS
SELECT id, title FROM product WHERE title ILIKE $1 ORDER BY id;

-- proc dropSales()
PREPARE drop_sales AS
DELETE FROM sale;
