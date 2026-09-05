CREATE TYPE kind AS ENUM ('A', 'B');

CREATE TABLE item (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL,
    price numeric(10, 2) NOT NULL DEFAULT 0,
    tags text[] NOT NULL,
    kinds kind[],
    created timestamptz NOT NULL DEFAULT now(),
    active boolean NOT NULL DEFAULT TRUE,
    stock integer NOT NULL DEFAULT 0,
    meta jsonb,
    ip inet,
    at time,
    span interval,
    key uuid NOT NULL DEFAULT gen_random_uuid(),
    CONSTRAINT item_in_stock_check CHECK (stock >= 0),
    CONSTRAINT item_priced_check CHECK (price > 0 OR NOT active)
);
CREATE INDEX item_stock_idx ON item (stock);
CREATE INDEX item_active_created_idx ON item (active, created);

-- func cheap(max: Decimal): List<(String, Decimal)>
PREPARE cheap(numeric) AS
SELECT item.name, item.price
FROM item
WHERE item.price <= $1 AND item.active;

-- func add(name: String): Item
PREPARE add(text) AS
INSERT INTO item (name, price, tags)
VALUES ($1, 5, ARRAY['x'])
RETURNING *;
