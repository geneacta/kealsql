# KealSql — grammar

**Status: draft v1.** The syntax of a `.kealsql` file, in EBNF, with the
well-formedness rules the checker enforces on top of it and the SQL each
construct compiles to. The decisions behind it are in [DESIGN.md](DESIGN.md).

Notation: `X?` optional, `X*` zero or more, `X+` one or more, `"x"` a
literal token, `( … | … )` a choice. Terminal names in *italics* are Keal's
own lexical classes.

The guiding rule: **a `.kealsql` file is read by Keal's lexer and Keal's
expression parser.** KealSql adds two declarations (`table`, and `func`/`proc`
whose body is a query), one type form (`Ref<T.col>`), one value (`unknown`)
and one operator pair (`===` / `!==`). Everything else — precedence, strings,
`when`, `?:`, named arguments — is Keal, unchanged, so the selfhost
`lexing.keal` and the expression tiers of `parsing.keal` are reused, not
rewritten.

## 1. Lexical

Keal's lexer, plus:

| Addition | Class | Note |
|---|---|---|
| `unknown` | reserved value | beside `true`, `false`, `less`, `equal`, `greater` |
| `===`, `!==` | operator, equality tier | null-safe comparison; read by the parser as `==` / `!=` followed by an adjacent `=` |

**Contextual words** — a declaration where one follows, an ordinary name
everywhere else, in the manner of Keal's `record` / `weak` / `enum`:

| Word | Where it means something |
|---|---|
| `table` | before a name: `table User { … }` |
| `primary` `slug` `unique` `cascade` `restrict` `setNull` | before a column name, inside a `table` |
| `renamed` | `renamed(old)` before a column name, or before `table` |
| `stored` `pure` | `stored [pure] func` — a function that runs inside PostgreSQL |

**Nothing else is reserved.** `from`, `where`, `select`, `join`, `orderBy`,
`insert`, `update`, `delete`, `set`, `like` are methods and functions, not
keywords — which is why Keal could leave `where` unreserved and KealSql can
too. A column may be called `select` if its author insists.

## 2. File

```
File          = Item* ;
Item          = Import | EnumDecl | TableDecl | QueryDecl | MutationDecl | StoredDecl ;

Import        = "import" String ( "as" Ident )? ;
EnumDecl      = "enum" Ident "{" Ident ( "," Ident )* ","? "}" ;
```

An `import` brings another `.kealsql` file's tables and enums into scope,
resolved relative to the importing file, loaded once — Keal's rule.

## 3. Schema

```
TableDecl     = Renamed? "table" Ident "{" ( Column | TableConstraint )* "}" ;
Column        = ( Modifier | Renamed )* Ident ":" Type ;
Renamed       = "renamed" "(" Ident ")" ;                 (* the previous name, for the migration *)
Modifier      = "primary" | "slug" | "unique" | "cascade" | "restrict" | "setNull" ;
TableConstraint = "unique" "(" Ident ( "," Ident )+ ")" ;

Type          = ( ScalarType | RefType ) "?"? ;
ScalarType    = "Id" | "Slug" | "Serial" | "BigSerial"
              | "Int" | "BigInt" | "Float" | "Bool"
              | "String" ( "(" Integer ")" )?
              | "Uuid" | "Bytea" | "Date" | "Timestamp"
              | Ident ;                                   (* an enum *)
RefType       = "RefId"   "<" Ident ">"
              | "RefSlug" "<" Ident ">"
              | "Ref"     "<" ColumnRef ">" ;
ColumnRef     = Ident "." Ident ;                         (* Table.column *)
```

`ColumnRef` in type position is the one syntactic category Keal does not
have. It is its own production; the parser does not special-case `Ref<`.

### Well-formedness (checker, not grammar)

| Rule | Error when |
|---|---|
| `Id` ≡ `primary _: Serial`; `Slug` ≡ `slug _: String` | — |
| exactly one primary per table | none, or two (`Id` counts) |
| at most one slug per table | two (`Slug` counts) |
| `primary`, `slug`, `unique` exclude one another on a column | two on one column |
| `slug` column is `String` or `String(n)` | any other type |
| `primary` and `slug` columns are not `?` | `?` present |
| `RefId<T>` requires `T` to declare an `Id` | `T` used `primary … : X` — the message says `Ref<T.col>` |
| `RefSlug<T>` requires `T` to declare a `Slug` | `T` used `slug … : X` |
| `Ref<T.c>` requires `c` to be `primary`, `slug` or `unique` in `T` | otherwise |
| `cascade` / `restrict` / `setNull` only on a `Ref…` column | on a scalar |
| `setNull` only on a `Ref…?` | on a non-optional reference |
| `restrict` only on a `Ref…?` (to override its `setNull` default) | on a non-optional reference, where it is already the default |
| at most one of `cascade` / `restrict` / `setNull` | two |
| `unique(a, b)` names existing columns of the table, at least two | otherwise |
| `renamed(old)` at most once per column or table | twice |

### What it compiles to

| KealSql | SQL |
|---|---|
| `table User { … }` | `CREATE TABLE user (…)` |
| `id: Id` | `id serial PRIMARY KEY` |
| `primary token: Uuid` | `token uuid PRIMARY KEY` |
| `name: Slug` | `name text UNIQUE NOT NULL` |
| `slug code: String(8)` | `code varchar(8) UNIQUE NOT NULL` |
| `unique email: String` | `email text UNIQUE NOT NULL` |
| `email: String?` | `email text` |
| `unique(a, b)` | `UNIQUE (a, b)` |
| `author: RefId<User>` | `author integer NOT NULL REFERENCES user(id) ON DELETE RESTRICT` |
| `editor: RefId<User>?` | `editor integer REFERENCES user(id) ON DELETE SET NULL` |
| `cascade author: RefId<User>` | `… ON DELETE CASCADE` |
| `by: RefSlug<User>` | `by text NOT NULL REFERENCES user(name) ON DELETE RESTRICT ON UPDATE CASCADE` |
| `enum Suit { Hearts, Spades }` | `CREATE TYPE suit AS ENUM ('Hearts', 'Spades')` |
| `Ref<T.c>` column | the type of `c`; `REFERENCES t(c)` |

**Naming.** Identifiers are emitted in `snake_case`, unquoted: `fullName` →
`full_name`, `Post` → `post`, `RefId<User>` → `user(id)`. PostgreSQL folds
unquoted identifiers to lower case, and quoting them would make every `psql`
session pay for KealSql's spelling. A `.kealsql` name that collides with a
SQL reserved word (`user`, `order`, `group`) is emitted quoted, and the
compiler says so. *(Reversible decision.)*

## 4. Queries and mutations

```
QueryDecl     = "func" Ident "(" Params? ")" ":" ResultType Block ;
MutationDecl  = "proc" Ident "(" Params? ")" Block ;
Params        = Param ( "," Param )* ;
Param         = Ident ":" Type ( "=" Expr )? ;

ResultType    = "List" "<" RowType ">"          (* many rows *)
              | RowType "?"                     (* .first() *)
              | RowType                         (* .single(), or insert *)
              | ScalarType ;                    (* count(), exists() *)
RowType       = Ident                           (* a table: select(*) *)
              | "(" Type ( "," Type )+ ")"      (* a tuple: select(a, b) *)
              | Type ;                          (* one column: select(a) *)

Block         = "{" Binding* Pipeline "}" ;
Binding       = "val" Ident "=" Fragment ;
```

Keal's `func` / `proc` split does the work here. A `func` must produce a
value, so its pipeline ends in a terminal and its `insert` carries
`RETURNING *`. A `proc` produces nothing, so its pipeline is a mutation
without `RETURNING`, and a `proc` that ends in `select` is an error — Keal's
"using a `proc`'s result is an error" in the other direction.

Parameters become `$1`, `$2`, … in the emitted SQL, in declaration order.
A parameter of type `T?` may be compared; the result is `Bool3` (§5).

### Pipeline

```
Pipeline      = Fragment "." Terminal ( "." Fetch )?
              | Mutation ;

Fragment      = Source ( "." Stage )*
              | Ident ;                                    (* a val-bound fragment *)
Source        = "from" "(" Ident ( "as" Ident )? ")" ;

Stage         = "where"    "(" Expr ")"
              | "unless"   "(" Expr ")"
              | "join"     "(" Ident ( "as" Ident )? "," Expr ")"
              | "leftJoin" "(" Ident ( "as" Ident )? "," Expr ")"
              | "orderBy"  "(" OrderKey ( "," OrderKey )* ")"
              | "groupBy"  "(" Expr ( "," Expr )* ")"
              | "distinct" "(" ")"
              | "limit"    "(" Expr ")"
              | "offset"   "(" Expr ")" ;
OrderKey      = Expr ( "." ( "asc" | "desc" ) )? ( "." ( "nullsFirst" | "nullsLast" ) )? ;

Terminal      = "select" "(" ( "*" | Expr ( "," Expr )* ) ")"
              | "count"  "(" ")"
              | "exists" "(" ")" ;
Fetch         = "first" "(" ")"                            (* LIMIT 1, type T? *)
              | "single" "(" ")" ;                         (* exactly one, type T *)

Mutation      = "insert" "(" Ident "(" NamedArgs ")" ")"
              | "update" "(" Ident ")" ( "." "where" "(" Expr ")" )* "." "set" "(" NamedArgs ")"
              | "delete" "(" Ident ")" ( "." "where" "(" Expr ")" )* ;
NamedArgs     = Ident "=" Expr ( "," Ident "=" Expr )* ;
```

`from` comes first and `select` last: the evaluation order, not SQL's
writing order, so that at `select(id)` the checker already knows which table
`id` belongs to. Stages may repeat; two `where`s are `AND`ed. A `where` that
follows a `groupBy` is a `HAVING`. A `val`-bound fragment used inside another
pipeline (`id in recent.select(id)`) is a subquery; used as the source of
the final pipeline it is inlined.

`insert(Post(title = t, author = a))` is Keal's named-argument constructor
call. Columns not named take their SQL default; an `Id` never needs naming.
Naming a column that has no default and no `?` is an error, at compile time.

### What it compiles to

| KealSql | SQL |
|---|---|
| `from(Post)` | `FROM post` |
| `from(Post as p)` | `FROM post AS p` |
| `.where(p)` | `WHERE p` — `AND`ed if repeated; `HAVING` after `groupBy` |
| `.unless(p)` | `WHERE NOT (p)` |
| `.join(User as u, p.author == u.id)` | `JOIN user AS u ON p.author = u.id` |
| `.leftJoin(…)` | `LEFT JOIN … ON …` |
| `.orderBy(created.desc.nullsLast)` | `ORDER BY created DESC NULLS LAST` |
| `.groupBy(author)` | `GROUP BY author` |
| `.distinct()` | `SELECT DISTINCT` |
| `.limit(n)` / `.offset(n)` | `LIMIT n` / `OFFSET n` |
| `.select(*)` | `SELECT post.*` — typed as the table's record |
| `.select(id, title)` | `SELECT id, title` — typed `(Int, String)` |
| `.count()` | `SELECT count(*)` — `Int` |
| `.exists()` | `SELECT EXISTS (…)` — `Bool` |
| `.first()` | `LIMIT 1` — `T?` |
| `.single()` | `LIMIT 2`, the driver refuses 0 or 2 — `T` |
| `insert(Post(…))` in a `func` | `INSERT INTO post (…) VALUES ($1, …) RETURNING *` |
| `insert(Post(…))` in a `proc` | same, without `RETURNING` |
| `update(Post).where(p).set(title = t)` | `UPDATE post SET title = $1 WHERE p` |
| `delete(Post).where(p)` | `DELETE FROM post WHERE p` |

### Stored functions

```
StoredDecl    = "stored" "pure"? "func" Ident "(" Params? ")" ":" ScalarType KealBody ;
KealBody      = "{" ... "}" ;                              (* Keal, verbatim, to the matching brace *)
```

The signature is KealSql's — `Int`, `Float`, `Bool` or `String`, none
optional, no `String(n)` — and the body is Keal's: the parser finds the
matching brace and keeps the text for the Keal toolchain. `pure` declares
the function `IMMUTABLE`; without it, `VOLATILE`. A stored function is
called in expressions like any function, `slugify(name)`; its arguments
are checked against the signature, and an optional argument makes the
result optional — the function is STRICT, so a null never reaches it.

Inside the body, every `func` and `proc` of the file is a Keal function
with the same name and parameters, and a Keal result: `List<T>`, `T?`
for `first()`, `T` for `single()` and for a mutation with a row back,
`Int` for `count()`, `Bool` for `exists()`, nothing for a `proc`. A row is
a `record`: the table's, for `select(*)` and mutations; one named after
the query with a `Row` suffix and fields named after the selected columns,
for several columns. A query that fails is a Keal exception (`try` catches
it) carrying the query's name and PostgreSQL's message.

## 5. Expressions

Keal's expression grammar, Keal's precedence — *tightest binding last*:

```
not and or xor xnor nand nor implies
==  !=  ===  !==  <==>   <  <=  >  >=   is   in   ?:   ..
+  -   *  /  %   unary -   . ?. [] ()
```

Removed from Keal for v1: the bit operators, `**` and `^/`, lambdas,
assignment, `while` / `for`. Added: `===` / `!==` at the equality tier, and
`unknown`.

### Names

A bare identifier in a pipeline resolves against the function's parameters
first — the innermost scope, as in Keal — then against the columns of the
tables in scope, the `from` table and every `join`ed one. A column a
parameter shadows is reached qualified: `where(Product.sku == sku)`. An
ambiguous column (present in two tables in scope) is an error naming both;
qualify it with the table or its alias: `p.title`, `Post.title`. The same
parameter on both sides of a comparison is refused, naming the column.

A dotted path through a reference is an implicit join:

| Path | Type | Emitted join |
|---|---|---|
| `post.author.name` with `author: RefId<User>` | `String` | `JOIN user ON post.author = user.id` |
| `post.editor?.name` with `editor: RefId<User>?` | `String?` | `LEFT JOIN user ON post.editor = user.id` |
| `post.editor.name` with `editor: RefId<User>?` | *error* | "`editor` is optional; write `editor?.name`" |

This is Keal's null safety doing SQL's join arithmetic: `.` through a
non-optional reference is an inner join, `?.` through an optional one is a
left join, and the type of the result says which happened.

### Typing rules

| Expression | Type |
|---|---|
| `a == b`, `a != b`, `<`, `<=`, `>`, `>=` — both operands non-optional | `Bool` |
| same, at least one operand `T?` | `Bool3` |
| `a == null`, `a != null` | `Bool` (`IS NULL` / `IS NOT NULL`) |
| `a === b`, `a !== b` | `Bool` always (`IS [NOT] DISTINCT FROM`) |
| `a <=> b`, both non-optional | `Comp` (a `CASE` on `<` and `=`) |
| `a <=> b`, an operand `T?` | `Comp?` |
| `not p`, `p and q`, … with a `Bool3` operand | `Bool3`, Kleene tables |
| `a ?: b` with `a: T?`, `b: T` | `T` (`COALESCE`) |
| `when { … }` | the arms' common type (`CASE WHEN`) |
| `x in [a, b]` | `Bool` / `Bool3` as for `==` (`IN (…)`) |
| `x in fragment.select(c)` | same (`IN (SELECT …)`) |
| `s.like(p)`, `s.ilike(p)` | `Bool` / `Bool3` (`LIKE` / `ILIKE`) |
| `s.lower()`, `s.upper()`, `s.length()`, `s.trim()` | `String` / `Int`, `?`-preserving |
| `count(*)`, `count(c)`, `sum(c)`, `avg(c)`, `min(c)`, `max(c)` | aggregates; `sum`/`avg`/`min`/`max` of an empty group are `T?` |
| `a <==> b` | `Bool`, "does the order separate them" — an `Ord` question, kept for symmetry with Keal; rarely useful in SQL |

`where(p)` and `unless(p)` accept `Bool` or `Bool3`. On `Bool3` the emitted
`WHERE` keeps `true` rows only, and the checker warns when `p` is a plain
`==` / `!=` on an optional column: *"`email` is `String?`; rows where it is
null are dropped — `!==` if that is not what you mean"*.

Aggregates appear only in `select` (and in a `where` after `groupBy`). A
`select` that mixes an aggregate with a non-aggregated, non-grouped column is
an error — the one SQL only reports at run time.

## 6. A complete file

```
enum Status { Draft, Published }

table User {
    id:      Id
    name:    Slug
    unique email: String
    bio:     String?
}

table Post {
    id:       Id
    cascade author: RefId<User>
    editor:   RefId<User>?
    title:    String
    status:   Status
    created:  Timestamp
}

func byAuthor(name: String): List<(Int, String)> {
    from(Post as p)
        .where(p.author.name == name)
        .where(status == Published)
        .orderBy(created.desc)
        .select(p.id, p.title)
}

func editorOf(post: Int): String? {
    from(Post).where(id == post).select(editor?.name).first()
}

func drafts(): Int {
    from(Post).where(status == Draft).count()
}

func publish(post: Int): Post {
    update(Post).where(id == post).set(status = Published)
}

proc forget(user: RefId<User>) {
    delete(Post).where(author == user)
}
```

Each `func` and `proc` is emitted as a `PREPARE`, so the output loads into
`psql` as it is and every query is a prepared statement, its parameters
`$1`, `$2`, … in declaration order. An implicit join is aliased by the
reference column that asked for it. For `byAuthor`:

```sql
-- func byAuthor(name: String): List<(Int, String)>
PREPARE by_author(text) AS
SELECT p.id, p.title
FROM post AS p
JOIN "user" AS author ON p.author = author.id
WHERE author.name = $1 AND p.status = 'Published'
ORDER BY p.created DESC;
```

For `editorOf` — the `?.` became a `LEFT JOIN`, and the result type `String?`
says a post with no editor answers `null` rather than vanishing:

```sql
-- func editorOf(post: Int): String?
PREPARE editor_of(integer) AS
SELECT editor.name
FROM post
LEFT JOIN "user" AS editor ON post.editor = editor.id
WHERE post.id = $1
LIMIT 1;
```

The whole file, with its expected output, is `tests/cases/blog.kealsql`.
The `Bool3` warning of §5 is emitted as a `-- warning file:L:C ...` comment
line above the statement it concerns, so the output stays loadable.

## 7. The command

```
kealsql file.kealsql                                   the SQL: schema, then one PREPARE per func / proc
kealsql --migrate file.kealsql [--db NAME] [--destructive]
                                                       the migration from a live database to the file

kealsql --plkeal DIR file.kealsql                      the stored functions as DIR/<stem>.keal and DIR/build.sh
kealsql --lib PATH file.kealsql                        the SQL, its CREATE FUNCTIONs naming that library
```

`--migrate` reads the database through `psql` — `--db` is its `-d`; without
it the `PG*` environment and `~/.pgpass` decide — and prints `ALTER`,
`CREATE` and `DROP` statements to review. Destructive statements are held
back as comments unless `--destructive`; `renamed(old)` is what makes a
rename a rename rather than a drop and an add. [DESIGN.md](DESIGN.md) §3
has the rules.

`--plkeal` writes the Keal program and the build script for the shared
library of a file's `stored func`s; `build.sh` needs `keal` (or `KEAL=`),
a C compiler, and `pg_config` for the server headers. The file's SQL then
loads with `--lib DIR/<stem>.so` (without it, `$libdir/<stem>`).
[DESIGN.md](DESIGN.md) §1 has the mechanism.

## 8. Implementation notes

* **Lexer:** `keal/selfhost/lexing.keal`, imported from the pinned `keal`
  dependency (`import "dep:keal/selfhost/lexing.keal"`) — its public face
  is `lexFile`, `Token`, `Part`, `describeToken`, `tokenDumpLine`,
  `lexErrorPrefix`, promised by Keal since `0f2e5e9`. KealSql's three
  lexical additions are read by the parser on Keal's tokens: `===` / `!==`
  are `==` / `!=` with an adjacent `=`, and `unknown` is the identifier in
  value position, refused as a name.
* **Parser:** KealSql's own, `src/parser.keal`, ~450 lines. Keal's
  expression tiers were not copied: they build Keal's AST, and KealSql's
  is smaller. The precedence table is Keal's, connective mixing is refused
  as Keal refuses it, and two leniencies are KealSql's: a `;` the lexer put
  at a line end is dropped when a `.` follows (a chain continued on the
  next line), and `unless` is accepted as a name after a `.`.
* **Pipeline:** parsed as an ordinary Keal method chain — it *is* one
  syntactically — and recognised after parsing by the checker
  (`src/compile.keal`), which flattens the chain and walks it from
  `from(...)` outward. No grammar special-case; the errors ("`select` ends
  the query", "`set` belongs to `update`") are checker errors with
  positions.
* **Checking and emission are one pass.** Every expression compiles to a
  `Val`: its SQL and its type, plus the column it names when it names one,
  which is what a reference path continues from. A `Plan` gathers the
  clauses of one SELECT; rendering it is the last step.
* **Migrations:** `src/catalog.keal` reads `pg_catalog` in one `psql` round
  trip (`runCommand` with the script on standard input) into a `Live`
  model; `src/migrate.keal` diffs it against the resolved schema and
  renders `Step`s, each additive or destructive with its reason.
* **Tests:** `tests/run.sh` — each `tests/cases/X.kealsql` must produce
  exactly `X.sql`, each `tests/errors/X.kealsql` exactly `X.err`, the way
  Keal's suite compares engine output byte for byte. With PostgreSQL on the
  machine, every case is loaded and executed, and every
  `tests/migrations/X/` is migrated, applied in one transaction, and
  diffed again until it settles.
