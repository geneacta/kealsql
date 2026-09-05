CREATE TYPE role AS ENUM ('Admin', 'Member');

CREATE TABLE org (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL
);

CREATE TABLE account (
    id serial PRIMARY KEY,
    org text NOT NULL REFERENCES org(name) ON DELETE RESTRICT ON UPDATE CASCADE,
    login varchar(32) UNIQUE NOT NULL,
    role role NOT NULL,
    age integer,
    UNIQUE (org, login)
);

CREATE TABLE session (
    token uuid PRIMARY KEY,
    account integer NOT NULL REFERENCES account(id) ON DELETE RESTRICT,
    note text
);

CREATE TABLE audit (
    id serial PRIMARY KEY,
    session uuid NOT NULL REFERENCES session(token) ON DELETE RESTRICT,
    by_login varchar(32) NOT NULL REFERENCES account(login) ON DELETE CASCADE
);

-- func adults(): List<Account>
PREPARE adults() AS
SELECT account.*
FROM account
WHERE account.age >= 18;

-- func withoutAge(): List<String>
PREPARE without_age() AS
SELECT account.login
FROM account
WHERE account.age IS NULL;

-- func sameAge(years: Int?): List<Int>
-- warning tests/cases/features.kealsql:43:29 this `==` can be `unknown`; rows where it is are dropped, and `===` treats null as a value
PREPARE same_age(integer) AS
SELECT account.id
FROM account
WHERE account.age = $1;

-- func sameAgeStrict(years: Int?): List<Int>
PREPARE same_age_strict(integer) AS
SELECT account.id
FROM account
WHERE account.age IS NOT DISTINCT FROM $1;

-- func crowdedRoles(): List<(Role, Int)>
PREPARE crowded_roles() AS
SELECT account.role, count(*)
FROM account
GROUP BY account.role
HAVING count(*) > 1;

-- func label(acc: Int): String?
PREPARE label(integer) AS
SELECT CASE account.role WHEN 'Admin' THEN 'admin' WHEN 'Member' THEN 'member' END
FROM account
WHERE account.id = $1
LIMIT 1;

-- func orgOf(acc: Int): String?
PREPARE org_of(integer) AS
SELECT org.name
FROM account AS a
JOIN org ON a.org = org.name
WHERE a.id = $1
LIMIT 1;

-- func auditNotes(): List<(Int, String)>
PREPARE audit_notes() AS
SELECT au.id, COALESCE(session.note, '')
FROM audit AS au
JOIN session ON au.session = session.token
ORDER BY au.id;

-- func oldMembers(): List<Int>
PREPARE old_members() AS
SELECT account.id
FROM account
WHERE account.id IN (SELECT account.id FROM account WHERE account.role = 'Member') AND COALESCE(account.age, 0) > 60;

-- func hasLogin(l: String): Bool
PREPARE has_login(text) AS
SELECT EXISTS (
    SELECT 1
    FROM account
    WHERE account.login = $1
);

-- func admins(): Int
PREPARE admins() AS
SELECT count(*)
FROM account
WHERE account.role = 'Admin' AND account.age IS NOT NULL;

-- func page(n: Int): List<String>
PREPARE page(integer) AS
SELECT DISTINCT account.login
FROM account
ORDER BY account.age DESC NULLS LAST, account.login
LIMIT 10
OFFSET $1 * 10;

-- func byAccount(acc: Int): List<(Int, String)>
PREPARE by_account(integer) AS
SELECT a.id, a.by_login
FROM session AS s
JOIN audit AS a ON a.session = s.token
WHERE s.account = $1;

-- func search(pattern: String): List<String>
PREPARE search(text) AS
SELECT account.login
FROM account
WHERE NOT (account.login LIKE $1 OR lower(account.login) LIKE 'x' || '%');

-- func newAccount(org: String, login: String, role: Role): Account
PREPARE new_account(text, text, role) AS
INSERT INTO account (org, login, role)
VALUES ($1, $2, $3)
RETURNING *;

-- proc rename(acc: Int, newLogin: String)
PREPARE rename(integer, text) AS
UPDATE account
SET login = $2, age = NULL
WHERE account.id = $1;

-- proc dropSessions(acc: Int)
PREPARE drop_sessions(integer) AS
DELETE FROM session
WHERE session.account = $1;
