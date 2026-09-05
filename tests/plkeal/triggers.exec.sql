-- Run after triggers.sql, with the library built and loaded; the output is triggers.exec.out.
INSERT INTO product (sku, price) VALUES ('ham-1', 15), ('saw-1', 22.50);
INSERT INTO product (sku, price, note) VALUES ('drl-1', 89, 'cordless');
SELECT sku, price, stock, updates, note FROM product ORDER BY sku;
UPDATE product SET stock = 5 WHERE sku = 'HAM-1';
UPDATE product SET stock = 7, price = 16 WHERE sku = 'HAM-1';
SELECT sku, stock, updates FROM product ORDER BY sku;
\set ON_ERROR_STOP off
\set VERBOSITY terse
UPDATE product SET stock = -1 WHERE sku = 'SAW-1';
\set ON_ERROR_STOP on
SELECT sku, stock, updates FROM product WHERE sku = 'SAW-1';
DELETE FROM product WHERE sku = 'HAM-1';
EXECUTE audits;
SELECT 'still alive' AS after_error;
