CREATE TYPE billing.status AS ENUM ('Open', 'Paid');
CREATE TABLE billing.invoice (
    id serial PRIMARY KEY,
    customer integer NOT NULL REFERENCES billing.customer(id) ON DELETE CASCADE,
    status billing.status NOT NULL DEFAULT 'Open',
    cents integer NOT NULL,
    due date
);
CREATE INDEX invoice_due_idx ON billing.invoice (due);
ALTER TABLE billing.customer ADD COLUMN since date;
CREATE VIEW billing.unpaid AS
    SELECT i.id AS invoice, i.cents AS cents
    FROM billing.invoice AS i
    WHERE i.status = 'Open';
COMMENT ON VIEW billing.unpaid IS 'kealsql:387767152';
