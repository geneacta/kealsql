<p align="center"><img src="assets/kealsql.png" alt="KealSql" width="360"></p>

# KealSql

A Keal-shaped language over PostgreSQL. A `.kealsql` file declares a schema
and queries in the syntax of [Keal](https://github.com/geneacta/keal), and the
compiler — itself a Keal program — turns them into plain PostgreSQL SQL,
ahead of time, type-checked against the schema.

```
table User {
    id:    Id
    name:  Slug
    email: String?
}

table Post {
    id:      Id
    cascade author: RefId<User>
    editor:  RefId<User>?
    title:   String
}

func byAuthor(name: String): List<(Int, String)> {
    from(Post as p)
        .where(p.author.name == name)
        .select(p.id, p.title)
}

func editorOf(post: Int): String? {
    from(Post).where(id == post).select(editor?.name).first()
}
```

```
$ keal src/main.keal blog.kealsql
CREATE TABLE "user" (
    id serial PRIMARY KEY,
    name text UNIQUE NOT NULL,
    email text
);
...
-- func editorOf(post: Int): String?
PREPARE editor_of(integer) AS
SELECT editor.name
FROM post
LEFT JOIN "user" AS editor ON post.editor = editor.id
WHERE post.id = $1
LIMIT 1;
```

The `?.` became a `LEFT JOIN`, and the result type `String?` says a post
with no editor answers `null` rather than vanishing. That is the point of
the project: Keal's null safety, closed `when`, and records, applied to a
schema — so that a query which reads a column the schema does not have, or
puts `NULL` where the schema forbids it, is a **compile error**, not a
surprise at run time.

It is **not a fork of PostgreSQL.** The output is SQL for an unmodified
server; nothing runs but the planner PostgreSQL already has.

* [DESIGN.md](DESIGN.md) — the decisions and the reasons: why a transpiler,
  `Bool3`, `Id` / `Slug`, references, migrations.
* [GRAMMAR.md](GRAMMAR.md) — the syntax, the well-formedness rules, and
  what each construct compiles to.

## Running it

KealSql needs the Keal toolchain (1.2.0 or later) on the path, or beside the
repository at `../keal`.

```sh
keal src/main.keal file.kealsql        # print the SQL
tests/run.sh                            # the suite: every case, byte for byte
```

When PostgreSQL's `initdb` is on the machine, the suite also starts a
private server in a temporary directory — no root, no configuration — loads
every case's SQL into a fresh database, runs the `*.exec.sql` beside it in
the same session, and compares the rows to `*.exec.out`. Without `initdb`
it says so and compares the SQL only.

The compiler runs on Keal's bytecode VM. `keal build` refuses it for now —
its error path returns `Nothing`, which the C backend does not cover yet —
and says so by name rather than mis-compiling, which is Keal's rule.

## Layout

| | |
|---|---|
| `src/lexing.keal` | Keal's own lexer, vendored from `keal/selfhost` with the `===` / `!==` tokens and the `unknown` word added; `ci/sync-lexer.sh` shows the diff |
| `src/ast.keal` | the syntax tree |
| `src/parser.keal` | items (`table`, `enum`, `func`, `proc`) and Keal's expression precedence |
| `src/schema.keal` | the resolved schema and SQL naming |
| `src/compile.keal` | checker and emitter, one pass: a `Val` is an expression's SQL and its type |
| `src/main.keal` | the command |
| `tests/cases/*.kealsql` | each compiles to exactly its `.sql` |
| `tests/errors/*.kealsql` | each fails with exactly its `.err` |
| `tests/cases/*.exec.sql` | run on PostgreSQL after the case's SQL; the rows must be exactly `.exec.out` |

## Status

v1 covers the schema (`table`, `enum`, keys, references, `on delete`), the
DDL, and queries: `from` / `where` / `unless` / `join` / `leftJoin` /
`orderBy` / `groupBy` / `distinct` / `limit` / `offset`, the terminals
`select` / `count` / `exists` with `first` / `single`, subqueries through
`val`-bound fragments and `in`, `insert` / `update` / `delete`, `when`,
`?:`, the eight connectives with Kleene's tables on `Bool3`, and reference
paths as implicit joins. Not yet: the migration diff against a live
database, and `plkeal`.

Licensed under Apache-2.0, like Keal.
