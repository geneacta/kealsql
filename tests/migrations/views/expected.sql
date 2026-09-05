ALTER TABLE product ADD COLUMN stock integer NOT NULL DEFAULT 0;
DROP VIEW cheap;
DROP VIEW dear;
CREATE VIEW cheap AS
    SELECT product.sku, product.price
    FROM product
    WHERE product.price < 20;
COMMENT ON VIEW cheap IS 'kealsql:447264543';
CREATE VIEW stocked AS
    SELECT product.sku, product.stock
    FROM product
    WHERE product.stock > 0;
COMMENT ON VIEW stocked IS 'kealsql:745962133';
