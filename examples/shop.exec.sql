-- Run after shop.sql in the same session; the output is shop.exec.out.
EXECUTE new_customer('ada@x', 'Ada', '2026-01-10');
EXECUTE new_customer('bob@x', 'Bob', '2026-02-20');
EXECUTE new_customer('cy@x', 'Cy', '2026-03-30');
INSERT INTO category (slug, title, parent) VALUES ('tools', 'Tools', NULL), ('hand-tools', 'Hand tools', 1), ('power-tools', 'Power tools', 1), ('garden', 'Garden', NULL);
INSERT INTO product (sku, title, category, price_cents, stock, weight_kg, retired) VALUES
    ('HAM-1', 'Hammer', 2, 1500, 12, 0.9, false),
    ('SAW-1', 'Hand saw', 2, 2200, 3, NULL, false),
    ('DRL-1', 'Drill', 3, 8900, 7, 2.4, false),
    ('MOW-1', 'Mower', 4, 45000, 1, 32.0, false),
    ('OLD-1', 'Old thing', 2, 100, 0, NULL, true);
EXECUTE top_level_categories;
EXECUTE subcategories('tools');
EXECUTE in_category('hand-tools');
EXECUTE low_stock(5);
EXECUTE heavy_or_light;
EXECUTE product_by_sku('DRL-1');
EXECUTE product_by_sku('NOPE');
-- ada buys a hammer and a drill, pays; bob starts a cart and leaves it
EXECUTE start_cart(1);
EXECUTE add_line(1, 1, 2, 1500);
EXECUTE add_line(1, 3, 1, 8900);
EXECUTE order_total(1);
EXECUTE order_lines(1);
EXECUTE place(1, '2026-04-01 10:00');
UPDATE "order" SET status = 'Paid' WHERE id = 1;
EXECUTE start_cart(2);
EXECUTE add_line(2, 4, 1, 45000);
EXECUTE open_cart(2);
EXECUTE open_cart(1);
EXECUTE orders_of('ada@x');
EXECUTE revenue_by_status;
EXECUTE big_spenders(10000);
EXECUTE big_spenders(20000);
EXECUTE never_ordered;
EXECUTE has_paid_orders(1);
EXECUTE has_paid_orders(2);
-- reviews
INSERT INTO review (product, author, rating, body) VALUES (3, 1, 'Five', 'Drills.'), (3, 2, 'Three', NULL), (1, 1, 'Four', 'Hits.');
EXECUTE average_rating(3);
EXECUTE average_rating(4);
EXECUTE reviews_with_text(3);
-- stock and retirement
EXECUTE restock('SAW-1', 10);
EXECUTE low_stock(5);
EXECUTE retire('SAW-1');
EXECUTE in_category('hand-tools');
-- a customer and everything of theirs goes; the unique(order, product) holds
EXECUTE forget_customer('ada@x');
SELECT count(*) AS orders, (SELECT count(*) FROM order_line) AS lines, (SELECT count(*) FROM review) AS reviews FROM "order";
\set ON_ERROR_STOP off
EXECUTE add_line(2, 4, 1, 45000);
SELECT 'still alive' AS after_error;
