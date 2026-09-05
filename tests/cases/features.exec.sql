-- Run after features.sql in the same session; the output is features.exec.out.
INSERT INTO org (name) VALUES ('acme');
EXECUTE new_account('acme', 'ada', 'Admin');
EXECUTE new_account('acme', 'bob', 'Member');
UPDATE account SET age = 70 WHERE login = 'bob';
EXECUTE adults;                 -- bob: ada's null age is unknown, dropped
EXECUTE without_age;            -- ada
EXECUTE same_age(NULL);         -- no rows: `=` NULL is unknown
EXECUTE same_age_strict(NULL);  -- ada: `===` treats null as a value
EXECUTE crowded_roles;          -- none: one account per role
EXECUTE label(1);               -- admin
EXECUTE org_of(2);              -- acme, joined on the slug
EXECUTE old_members;            -- bob
EXECUTE has_login('ada');
EXECUTE admins;                 -- 0: ada's age is null
EXECUTE page(0);
EXECUTE oldest_first;           -- bob first, ada's null last
EXECUTE search('a%');           -- bob: NOT (login LIKE 'a%' OR ...)
INSERT INTO session (token, account, note) VALUES ('11111111-1111-1111-1111-111111111111', 1, NULL);
INSERT INTO audit (session, by_login) VALUES ('11111111-1111-1111-1111-111111111111', 'ada');
EXECUTE audit_notes;            -- the null note becomes ''
EXECUTE by_account(1);
EXECUTE rename(2, 'robert');
SELECT login, age FROM account WHERE id = 2;
DELETE FROM audit;
EXECUTE drop_sessions(1);       -- allowed once nothing references the session
SELECT count(*) FROM session;
