CREATE SCHEMA IF NOT EXISTS billing;

CREATE TYPE billing.status AS ENUM ('Open', 'Paid');

CREATE TABLE billing.customer (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL
);

CREATE TABLE billing.invoice (
    id serial PRIMARY KEY,
    customer integer NOT NULL REFERENCES billing.customer(id) ON DELETE CASCADE,
    status billing.status NOT NULL DEFAULT 'Open',
    cents integer NOT NULL,
    due date
);
CREATE INDEX invoice_due_idx ON billing.invoice (due);

CREATE VIEW billing.unpaid AS
    SELECT i.id AS invoice, customer.name AS customer, i.cents AS cents
    FROM billing.invoice AS i
    JOIN billing.customer ON i.customer = customer.id
    WHERE i.status = 'Open';
COMMENT ON VIEW billing.unpaid IS 'kealsql:708703904';

-- func unpaidOf(name: String): List<(Int, Int)>
PREPARE unpaid_of(text) AS
SELECT u.invoice, u.cents
FROM billing.unpaid AS u
WHERE u.customer = $1
ORDER BY u.invoice;

-- func owed(): Int?
PREPARE owed AS
SELECT sum(invoice.cents)
FROM billing.invoice
WHERE invoice.status = 'Open'
LIMIT 2;

-- proc pay(invoice: Int)
PREPARE pay(integer) AS
UPDATE billing.invoice
SET status = 'Paid'
WHERE invoice.id = $1;

-- func bill(customer: Int, cents: Int): Invoice
PREPARE bill(integer, integer) AS
INSERT INTO billing.invoice (customer, cents)
VALUES ($1, $2)
RETURNING *;
