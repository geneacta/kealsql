-- Run after schema.sql in the same session; the output is schema.exec.out.
INSERT INTO billing.customer (name) VALUES ('ada'), ('bob');
EXECUTE bill(1, 1200);
EXECUTE bill(1, 800);
EXECUTE bill(2, 500);
EXECUTE unpaid_of('ada');
EXECUTE owed;
EXECUTE pay(1);
EXECUTE unpaid_of('ada');
EXECUTE owed;
SELECT nspname FROM pg_namespace WHERE nspname = 'billing';
