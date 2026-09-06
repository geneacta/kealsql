-- Run after setof.sql, with the library built and loaded; the output is setof.exec.out.
SELECT * FROM range(4);
SELECT count(*) FROM range(1000);
SELECT * FROM words('  keal  sql postgres ');
INSERT INTO product (sku, price, note) VALUES ('HAM', 15, NULL), ('SAW', 22, 'sharp'), ('DRL', 89, NULL);
SELECT sku, price, note FROM cheap(30);
SELECT p.sku FROM cheap(100) AS p WHERE p.note IS NOT NULL;
