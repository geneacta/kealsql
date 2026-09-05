CREATE TABLE category (
    id serial PRIMARY KEY,
    slug text UNIQUE NOT NULL,
    title text NOT NULL,
    parent integer REFERENCES category(id) ON DELETE SET NULL
);

CREATE TABLE product (
    id serial PRIMARY KEY,
    sku text UNIQUE NOT NULL,
    category integer NOT NULL REFERENCES category(id) ON DELETE RESTRICT,
    price numeric(10, 2) NOT NULL,
    meta jsonb
);

CREATE TABLE archive (
    id serial PRIMARY KEY,
    sku text NOT NULL,
    price numeric(10, 2) NOT NULL,
    note text NOT NULL DEFAULT 'archived'
);

CREATE VIEW priced_category AS
    SELECT p.category AS category, count(*) AS products, max(p.price) AS top
    FROM product AS p
    GROUP BY p.category;
COMMENT ON VIEW priced_category IS 'kealsql:466284405';

CREATE VIEW roots AS
    SELECT category.id, category.slug, category.title
    FROM category
    WHERE category.parent IS NULL;
COMMENT ON VIEW roots IS 'kealsql:992863952';

-- func categoryStats(): List<(Int, Int, Decimal?)>
PREPARE category_stats AS
SELECT s.category, s.products, s.top
FROM priced_category AS s
ORDER BY s.category;

-- func rootSlugs(): List<String>
PREPARE root_slugs AS
SELECT roots.slug
FROM roots
ORDER BY roots.slug;

-- func descendants(root: String): List<(String, Int)>
PREPARE descendants(text) AS
WITH RECURSIVE tree(id, slug, depth) AS (
    SELECT category.id, category.slug, 0 AS depth
    FROM category
    WHERE category.slug = $1
    UNION ALL
    SELECT c.id, c.slug, t.depth + 1 AS depth
    FROM category AS c
    JOIN tree AS t ON c.parent = t.id
)
SELECT tree.slug, tree.depth
FROM tree
ORDER BY tree.depth, tree.slug;

-- func archiveCheap(max: Decimal): Int
PREPARE archive_cheap(numeric) AS
SELECT count(*)
FROM archive
WHERE archive.price <= $1;

-- proc archive(max: Decimal)
PREPARE archive(numeric) AS
INSERT INTO archive (sku, price)
SELECT product.sku, product.price
FROM product
WHERE product.price <= $1;

-- proc tagWithCategory(category: String)
PREPARE tag_with_category(text) AS
UPDATE product AS p
SET meta = '{"tagged": true}'::jsonb
FROM category AS c
WHERE c.id = p.category AND c.slug = $1;

-- proc dropCategoryProducts(category: String)
PREPARE drop_category_products(text) AS
DELETE FROM product AS p
USING category AS c
WHERE c.id = p.category AND c.slug = $1;

-- func tagged(): List<(String, String?, Bool?)>
PREPARE tagged AS
SELECT product.sku, product.meta ->> 'tagged', product.meta ? 'tagged'
FROM product
WHERE product.meta IS NOT NULL
ORDER BY product.sku;

-- func withMeta(key: String): List<String>
PREPARE with_meta(text) AS
SELECT product.sku
FROM product
WHERE product.meta ? $1
ORDER BY product.sku;
