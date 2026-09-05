CREATE TYPE status AS ENUM ('Draft', 'Published');

CREATE TABLE "user" (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL,
    email text UNIQUE NOT NULL,
    bio text
);

CREATE TABLE post (
    id serial PRIMARY KEY,
    author integer NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    editor integer REFERENCES "user"(id) ON DELETE SET NULL,
    title text NOT NULL,
    status status NOT NULL,
    created timestamp NOT NULL
);

-- func byAuthor(name: String): List<(Int, String)>
PREPARE by_author(text) AS
SELECT p.id, p.title
FROM post AS p
JOIN "user" AS author ON p.author = author.id
WHERE author.name = $1 AND p.status = 'Published'
ORDER BY p.created DESC;

-- func editorOf(post: Int): String?
PREPARE editor_of(integer) AS
SELECT editor.name
FROM post
LEFT JOIN "user" AS editor ON post.editor = editor.id
WHERE post.id = $1
LIMIT 1;

-- func drafts(): Int
PREPARE drafts() AS
SELECT count(*)
FROM post
WHERE post.status = 'Draft';

-- func publish(post: Int): Post
PREPARE publish(integer) AS
UPDATE post
SET status = 'Published'
WHERE post.id = $1
RETURNING *;

-- proc forget(user: RefId<User>)
PREPARE forget(integer) AS
DELETE FROM post
WHERE post.author = $1;
