CREATE TYPE order_status AS ENUM ('Cart', 'Placed', 'Paid', 'Shipped', 'Cancelled');

CREATE TYPE rating AS ENUM ('One', 'Two', 'Three', 'Four', 'Five');

CREATE TABLE customer (
    id serial PRIMARY KEY,
    email text UNIQUE NOT NULL,
    name text NOT NULL,
    since date NOT NULL,
    credit integer NOT NULL
);

CREATE TABLE category (
    id serial PRIMARY KEY,
    slug text UNIQUE NOT NULL,
    title text NOT NULL,
    parent integer REFERENCES category(id) ON DELETE SET NULL
);

CREATE TABLE product (
    id serial PRIMARY KEY,
    sku text UNIQUE NOT NULL,
    title text NOT NULL,
    category integer NOT NULL REFERENCES category(id) ON DELETE RESTRICT,
    price_cents integer NOT NULL,
    stock integer NOT NULL,
    weight_kg double precision,
    retired boolean NOT NULL
);

CREATE TABLE "order" (
    id serial PRIMARY KEY,
    customer integer NOT NULL REFERENCES customer(id) ON DELETE CASCADE,
    status order_status NOT NULL,
    placed_at timestamp,
    note varchar(200)
);

CREATE TABLE order_line (
    id serial PRIMARY KEY,
    "order" integer NOT NULL REFERENCES "order"(id) ON DELETE CASCADE,
    product integer NOT NULL REFERENCES product(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    unit_cents integer NOT NULL,
    UNIQUE ("order", product)
);

CREATE TABLE review (
    id serial PRIMARY KEY,
    product integer NOT NULL REFERENCES product(id) ON DELETE CASCADE,
    author integer NOT NULL REFERENCES customer(id) ON DELETE CASCADE,
    rating rating NOT NULL,
    body text,
    UNIQUE (product, author)
);

-- func productBySku(sku: String): Product?
PREPARE product_by_sku(text) AS
SELECT product.*
FROM product
WHERE product.sku = $1
LIMIT 1;

-- func inCategory(slug: String): List<(String, String, Int)>
PREPARE in_category(text) AS
SELECT p.sku, p.title, p.price_cents
FROM product AS p
JOIN category ON p.category = category.id
WHERE category.slug = $1 AND NOT p.retired
ORDER BY p.title;

-- func topLevelCategories(): List<(String, String)>
PREPARE top_level_categories AS
SELECT category.slug, category.title
FROM category
WHERE category.parent IS NULL
ORDER BY category.title;

-- func subcategories(of: String): List<String>
-- warning examples/shop.kealsql:78:46 this `==` can be `unknown`; rows where it is are dropped, and `===` treats null as a value
PREPARE subcategories(text) AS
SELECT c.title
FROM category AS c
LEFT JOIN category AS parent ON c.parent = parent.id
WHERE parent.slug = $1
ORDER BY c.title;

-- func lowStock(threshold: Int): List<(String, Int)>
PREPARE low_stock(integer) AS
SELECT product.sku, product.stock
FROM product
WHERE product.stock < $1 AND NOT product.retired
ORDER BY product.stock, product.sku;

-- func heavyOrLight(): List<(String, String)>
PREPARE heavy_or_light AS
SELECT product.sku, CASE WHEN product.weight_kg IS NULL THEN 'unknown' WHEN product.weight_kg > 10.0 THEN 'heavy' ELSE 'light' END
FROM product
ORDER BY product.sku;

-- func openCart(customer: Int): Order?
PREPARE open_cart(integer) AS
SELECT "order".*
FROM "order"
WHERE "order".customer = $1 AND "order".status = 'Cart'
LIMIT 1;

-- func orderTotal(order: Int): Int?
PREPARE order_total(integer) AS
SELECT sum(l.quantity * l.unit_cents)
FROM order_line AS l
WHERE l."order" = $1
LIMIT 2;

-- func orderLines(order: Int): List<(String, Int, Int)>
PREPARE order_lines(integer) AS
SELECT product.title, l.quantity, l.unit_cents
FROM order_line AS l
JOIN product ON l.product = product.id
WHERE l."order" = $1
ORDER BY product.title;

-- func ordersOf(email: String): List<(Int, OrderStatus, Timestamp?)>
PREPARE orders_of(text) AS
SELECT o.id, o.status, o.placed_at
FROM "order" AS o
JOIN customer ON o.customer = customer.id
WHERE customer.email = $1
ORDER BY o.id DESC;

-- func revenueByStatus(): List<(OrderStatus, Int)>
PREPARE revenue_by_status AS
SELECT o.status, COALESCE(sum(l.quantity * l.unit_cents), 0)
FROM "order" AS o
JOIN order_line AS l ON l."order" = o.id
GROUP BY o.status
ORDER BY o.status;

-- func bigSpenders(minCents: Int): List<(String, Int)>
PREPARE big_spenders(integer) AS
SELECT c.email, COALESCE(sum(l.quantity * l.unit_cents), 0)
FROM customer AS c
JOIN "order" AS o ON o.customer = c.id
JOIN order_line AS l ON l."order" = o.id
WHERE o.status = 'Paid' OR o.status = 'Shipped'
GROUP BY c.email
HAVING sum(l.quantity * l.unit_cents) >= $1
ORDER BY c.email;

-- func neverOrdered(): List<String>
PREPARE never_ordered AS
SELECT customer.email
FROM customer
WHERE NOT (customer.id IN (SELECT "order".customer FROM "order" WHERE "order".status <> 'Cart'))
ORDER BY customer.email;

-- func hasPaidOrders(customer: Int): Bool
PREPARE has_paid_orders(integer) AS
SELECT EXISTS (
    SELECT 1
    FROM "order"
    WHERE "order".customer = $1 AND "order".status = 'Paid'
);

-- func averageRating(product: Int): Float?
PREPARE average_rating(integer) AS
SELECT avg(CASE review.rating WHEN 'One' THEN 1 WHEN 'Two' THEN 2 WHEN 'Three' THEN 3 WHEN 'Four' THEN 4 WHEN 'Five' THEN 5 END)
FROM review
WHERE review.product = $1
LIMIT 2;

-- func reviewsWithText(product: Int): List<(String, Rating, String)>
PREPARE reviews_with_text(integer) AS
SELECT author.name, r.rating, COALESCE(r.body, '')
FROM review AS r
JOIN customer AS author ON r.author = author.id
WHERE r.product = $1 AND r.body IS NOT NULL
ORDER BY r.id;

-- func newCustomer(email: String, name: String, since: Date): Customer
PREPARE new_customer(text, text, date) AS
INSERT INTO customer (email, name, since, credit)
VALUES ($1, $2, $3, 0)
RETURNING *;

-- func startCart(customer: Int): Order
PREPARE start_cart(integer) AS
INSERT INTO "order" (customer, status)
VALUES ($1, 'Cart')
RETURNING *;

-- proc addLine(order: Int, product: Int, quantity: Int, unitCents: Int)
PREPARE add_line(integer, integer, integer, integer) AS
INSERT INTO order_line ("order", product, quantity, unit_cents)
VALUES ($1, $2, $3, $4);

-- proc place(order: Int, at: Timestamp)
PREPARE place(integer, timestamp) AS
UPDATE "order"
SET status = 'Placed', placed_at = $2
WHERE "order".id = $1 AND "order".status = 'Cart';

-- proc restock(sku: String, by: Int)
PREPARE restock(text, integer) AS
UPDATE product
SET stock = product.stock + $2
WHERE product.sku = $1;

-- proc retire(sku: String)
PREPARE retire(text) AS
UPDATE product
SET retired = TRUE
WHERE product.sku = $1;

-- proc forgetCustomer(email: String)
PREPARE forget_customer(text) AS
DELETE FROM customer
WHERE customer.email = $1;
