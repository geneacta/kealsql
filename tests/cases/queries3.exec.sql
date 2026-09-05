-- Run after queries3.sql in the same session; the output is queries3.exec.out.
INSERT INTO category (slug, title, parent) VALUES ('tools', 'Tools', NULL), ('hand', 'Hand tools', 1), ('power', 'Power tools', 1), ('drills', 'Drills', 3), ('garden', 'Garden', NULL);
INSERT INTO product (sku, category, price, meta) VALUES ('HAM', 2, 15, NULL), ('SAW', 2, 22, NULL), ('DRL', 4, 89, '{"volts": 18}'), ('MOW', 5, 450, NULL);
EXECUTE category_stats;
EXECUTE root_slugs;
EXECUTE descendants('tools');
EXECUTE descendants('garden');
EXECUTE archive(30);
EXECUTE archive_cheap(100);
SELECT sku, price, note FROM archive ORDER BY sku;
EXECUTE tag_with_category('hand');
EXECUTE tagged;
EXECUTE with_meta('volts');
EXECUTE drop_category_products('drills');
SELECT sku FROM product ORDER BY sku;
