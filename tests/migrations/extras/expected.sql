ALTER TABLE item ALTER COLUMN price TYPE numeric(12, 2);
ALTER TABLE item ALTER COLUMN price SET DEFAULT 1;
ALTER TABLE item ALTER COLUMN stock DROP DEFAULT;
ALTER TABLE item ALTER COLUMN tags SET DEFAULT ARRAY[]::text[];
ALTER TABLE item ADD COLUMN created timestamptz NOT NULL DEFAULT now();
-- DESTRUCTIVE, held back (pass --destructive to emit it): fails if a row of `item` breaks `priced`
-- ALTER TABLE item ADD CONSTRAINT item_priced_check CHECK (price > 0);
DROP INDEX item_active_stock_idx;
CREATE INDEX item_stock_idx ON item (stock);
-- 1 statement held back
