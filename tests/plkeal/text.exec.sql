-- Run after text.sql, with the library built and loaded; the output is text.exec.out.
INSERT INTO "user" (name) VALUES ('Hello World'), ('Keal & SQL!!'), ('  42  ');
EXECUTE slugs;
EXECUTE long_names(6);
SELECT fib(50);
SELECT halve(5.0);
SELECT slugify(NULL) IS NULL AS strict_null;
\set ON_ERROR_STOP off
SELECT shout('x');
SELECT 'still alive' AS after_error;
