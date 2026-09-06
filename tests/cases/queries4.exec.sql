-- Run after queries4.sql in the same session; the output is queries4.exec.out.
INSERT INTO product (sku, price) VALUES ('A', 10), ('B', 60), ('C', 70);
EXECUTE bands;
REFRESH MATERIALIZED VIEW price_bands;
EXECUTE bands;
EXECUTE stamp('A', 'keal');
EXECUTE blobs;
EXECUTE stamped;
