-- The blog on SQLite: the same tables and rows; the function comes from the C program.
CREATE TABLE user (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, email TEXT);
CREATE TABLE post (id INTEGER PRIMARY KEY AUTOINCREMENT, author INTEGER NOT NULL REFERENCES user(id) ON DELETE CASCADE,
                   title TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN ('Draft', 'Published')));
WITH RECURSIVE g(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM g WHERE n < 19) INSERT INTO user (name) SELECT 'u' || n FROM g;
INSERT INTO user (name) VALUES ('ada');
WITH RECURSIVE g(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM g WHERE n < 400)
INSERT INTO post (author, title, status) SELECT 1 + (n % 20), 'post ' || n, CASE WHEN n % 2 = 0 THEN 'Published' ELSE 'Draft' END FROM g;
