CREATE TABLE product (
    id serial PRIMARY KEY,
    sku text UNIQUE NOT NULL,
    price numeric(10, 2) NOT NULL,
    stock integer NOT NULL DEFAULT 0,
    updates integer NOT NULL DEFAULT 0,
    note text
);

CREATE TABLE audit (
    id serial PRIMARY KEY,
    sku text NOT NULL,
    change text NOT NULL
);

CREATE OR REPLACE FUNCTION kealsql_trg_normalize_sku() RETURNS trigger
    AS '$libdir/triggers', 'kealsql_trg_normalize_sku' LANGUAGE C;
CREATE OR REPLACE TRIGGER normalize_sku BEFORE INSERT ON product
    FOR EACH ROW EXECUTE FUNCTION kealsql_trg_normalize_sku();

CREATE OR REPLACE FUNCTION kealsql_trg_count_updates() RETURNS trigger
    AS '$libdir/triggers', 'kealsql_trg_count_updates' LANGUAGE C;
CREATE OR REPLACE TRIGGER count_updates BEFORE UPDATE ON product
    FOR EACH ROW EXECUTE FUNCTION kealsql_trg_count_updates();

CREATE OR REPLACE FUNCTION kealsql_trg_audit_insert() RETURNS trigger
    AS '$libdir/triggers', 'kealsql_trg_audit_insert' LANGUAGE C;
CREATE OR REPLACE TRIGGER audit_insert AFTER INSERT ON product
    FOR EACH ROW EXECUTE FUNCTION kealsql_trg_audit_insert();

CREATE OR REPLACE FUNCTION kealsql_trg_audit_delete() RETURNS trigger
    AS '$libdir/triggers', 'kealsql_trg_audit_delete' LANGUAGE C;
CREATE OR REPLACE TRIGGER audit_delete AFTER DELETE ON product
    FOR EACH ROW EXECUTE FUNCTION kealsql_trg_audit_delete();

-- proc log(sku: String, change: String)
PREPARE log(text, text) AS
INSERT INTO audit (sku, change)
VALUES ($1, $2);

-- func audits(): List<(String, String)>
PREPARE audits AS
SELECT audit.sku, audit.change
FROM audit
ORDER BY audit.id;
