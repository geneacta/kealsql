CREATE TYPE status AS ENUM ('Draft', 'Published');

CREATE TABLE "user" (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL,
    karma integer NOT NULL
);

CREATE TABLE post (
    id serial PRIMARY KEY,
    author integer NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    title text NOT NULL,
    status status NOT NULL,
    score integer
);

CREATE OR REPLACE FUNCTION total_score(text) RETURNS bigint
    AS '$libdir/spi', 'kealsql_total_score' LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION describe(text) RETURNS text
    AS '$libdir/spi', 'kealsql_describe' LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION safe_award(text, bigint) RETURNS text
    AS '$libdir/spi', 'kealsql_safe_award' LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION draft_and_count(text, text) RETURNS bigint
    AS '$libdir/spi', 'kealsql_draft_and_count' LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION award_big(text) RETURNS text
    AS '$libdir/spi', 'kealsql_award_big' LANGUAGE C STRICT;

-- func userNamed(who: String): User?
PREPARE user_named(text) AS
SELECT "user".*
FROM "user"
WHERE "user".name = $1
LIMIT 1;

-- func posts(by: Int): List<(Int, String, Int?)>
PREPARE posts(integer) AS
SELECT post.id, post.title, post.score
FROM post
WHERE post.author = $1
ORDER BY post.id;

-- func published(): Int
PREPARE published AS
SELECT count(*)
FROM post
WHERE post.status = 'Published';

-- func hasDrafts(by: Int): Bool
PREPARE has_drafts(integer) AS
SELECT EXISTS (
    SELECT 1
    FROM post
    WHERE post.author = $1 AND post.status = 'Draft'
);

-- func newPost(by: Int, heading: String): Post
PREPARE new_post(integer, text) AS
INSERT INTO post (author, title, status)
VALUES ($1, $2, 'Draft')
RETURNING *;

-- proc award(who: Int, points: Int)
PREPARE award(integer, integer) AS
UPDATE "user"
SET karma = $2
WHERE "user".id = $1;
