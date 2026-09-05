-- Run after spi.sql, with the library built and loaded; the output is spi.exec.out.
INSERT INTO "user" (name, karma) VALUES ('ada', 10), ('bob', 0);
INSERT INTO post (author, title, status, score) VALUES (1, 'One', 'Published', 5), (1, 'Two', 'Draft', NULL), (1, 'Three', 'Published', 7);
SELECT total_score('ada'), total_score('bob'), total_score('nobody');
SELECT describe('ada');
SELECT describe('bob');
SELECT safe_award('ada', 42), safe_award('nobody', 1);
SELECT karma FROM "user" WHERE name = 'ada';
SELECT draft_and_count('bob', 'Four');
SELECT id, author, title, status FROM post WHERE title = 'Four';
\set ON_ERROR_STOP off
SELECT describe('nobody');
SELECT award_big('ada');
SELECT karma FROM "user" WHERE name = 'ada';
SELECT 'still alive' AS after_error;
