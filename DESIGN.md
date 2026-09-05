# KealSql — design notes

**Status: draft.** Decisions taken so far, and the reasons. Open questions at
the end.

KealSql is a Keal-shaped language over PostgreSQL. A `.kealsql` file declares
a schema and queries in the syntax of [Keal](../keal), and the KealSql
compiler turns them into plain PostgreSQL SQL, ahead of time, type-checked
against the schema.

It is **not a fork of PostgreSQL**, and its value is not the parentheses.
Replacing `SELECT * FROM t` with `select(*).from(t)` buys nothing on its own.
What KealSql buys is what Keal's type system already knows how to do —
null safety, closed `when`, records — applied to a schema, so that a query
that reads a column the schema does not have, or puts `NULL` where the schema
forbids it, is a **compile error**.

## 1. Architecture: a transpiler

`.kealsql` → SQL text → an unmodified PostgreSQL. Written in Keal.

Why not a fork (patching `gram.y`, dispatching in `raw_parser()`):

* Query performance is a property of the SQL emitted and of the planner, not
  of the front-end. The parser costs microseconds. A fork improves nothing
  unless it touches the executor or the storage — a different project.
* A fork must be rebased on every major release, cannot run on managed
  hosting, and blinds the whole ecosystem (pg_dump, ORMs, migration tools,
  monitoring).

Why not a wire-protocol proxy: it adds a network hop per query. It is the
one option that *costs* performance.

Why the transpiler is the fast option, not the compromise: the SQL is built
**at compile time**, so a query is a constant string plus parameters —
exactly a hand-written prepared statement, preparable at connection open
because it is known in advance. (jOOQ builds its SQL string on every call, at
run time.) The compiler can also *refuse* slow patterns — N+1, `like "%x"`
without a trigram index, a join on an unindexed column — instead of letting
them through.

**`plkeal` — shipped, for pure functions.** Keal compiles through C11 and
has C interop, so a function written in Keal becomes a `LANGUAGE C`
function — the fastest procedural language PostgreSQL has, against an
interpreted PL/pgSQL:

```
stored pure func slugify(s: String): String { ...ordinary Keal... }

func slugs(): List<(String, String)> {
    from(User).select(name, slugify(name))       // typed, like any function
}
```

`kealsql --plkeal DIR file.kealsql` writes a Keal program (the functions
verbatim, a `try` guard around each, and a `native` block with one
PostgreSQL entry point per function) and a `build.sh` that runs
`keal emit-c` and the C compiler against the server headers. The file's
ordinary SQL output carries the `CREATE FUNCTION ... LANGUAGE C STRICT`
statements (`--lib` names the library; `pure` adds `IMMUTABLE`). Values
cross as `KealStr*`, `int64_t`, `double`, `bool` — `Int`, `Float`, `Bool`,
`String`, none optional: the functions are STRICT, so PostgreSQL answers
null to a null without calling them. A panic inside (`throw`, overflow, a
bad index) is caught by the guard *in Keal*, read by the entry point after
every Keal frame has returned, and only then raised with `ereport` — which
is the rule below, obeyed. The suite builds the library, loads it, runs
the functions from prepared statements, and checks that a panic is a SQL
error and the backend is still there afterwards.

Not in this version: reaching the database from inside a stored function
(SPI). That is the case where PostgreSQL would `longjmp` *through* Keal,
and it waits for the shim discipline below to be applied to every SPI
call. Two things the runtime needed, found by doing it: the program's
`main` is what interns the string literals, so the entry points call
`keal_init_literals()` from `_PG_init`; and a global must be right as C
zeroes it (`var x: String? = null`), because that `main` never runs.

The issue the SPI step must settle: PostgreSQL reports errors with
`longjmp` (`ereport`) and allocates with `palloc`. Measured on the Keal side
(keal `db49bf4`, `docs/interop.md`): the Keal runtime uses no `setjmp`, it
unwinds by poisoned returns, so a foreign `longjmp` over Keal frames leaks
(the scope's releases and `deinit`s never run) but never double-frees. What
bites is `keal_try_depth`: a `try` increments it before its body and
decrements after, a `longjmp` skips the decrement, and from then on every
panic on that thread believes a `catch` is waiting — it records the message
and *returns a harmless value* instead of failing. A stored procedure would
answer wrongly in silence. **The rule:** catch the jump in the innermost C
shim (`PG_TRY` / `PG_CATCH`) and return normally, so no `longjmp` ever
crosses a Keal frame; failing that, save `keal_try_depth` and
`keal_unwinding` before the call and restore them after.

## 2. Types

### Nullability is `T?`

A column of type `String` is `NOT NULL`. A column of type `String?` is
nullable. Keal's `?.`, `?:`, `!!` and smart casts apply. The checker refuses
a `NULL` — statically — where the schema does not admit one.

### `Bool3`: SQL's three-valued logic, as a primitive

SQL's boolean has three values: `true`, `false`, `unknown`. `unknown` is
literally `NULL::boolean`; `NULL = 'a'` is `unknown`, `not unknown` is
`unknown`, and `WHERE` keeps only the rows where the predicate is `true` —
`unknown` rows are dropped silently. This is the source of the classic
`WHERE x != 'a'` bug that forgets the NULLs.

KealSql makes it a primitive, `Bool3`, with values `true`, `false`,
`unknown` written as bare words — following the precedent Keal set with
`Comp` beside `Bool`: one word, no methods, a `when` over it closes without
`else`.

The key property: **`Bool3` appears only when an operand is nullable.**

```
String  == String   → Bool      // two NOT NULL columns: ordinary logic
String? == String   → Bool3     // the type says you are in three-valued territory
```

Most queries stay in plain `Bool`. The checker knows exactly where
three-valued logic enters, and can warn: *"`email` is `String?`; this
comparison can be `unknown` and those rows will be dropped — did you mean
`email !== "a"`?"*

Two rules reconcile Keal's `==` with SQL's `=`:

1. **The `null` literal is special.** In Keal, `s == null` on a `String?` is a
   `Bool` — null is a value. In SQL, `s = NULL` is *always* `unknown`, the
   classic bug. KealSql compiles `x == null` to `x IS NULL` and `x != null`
   to `x IS NOT NULL`: both `Bool`. Keal's meaning survives, and it is what
   everyone means.
2. **Between two expressions**, `==` stays SQL's `=`: `Bool3` when an operand
   is nullable. It is deliberately *not* compiled to `IS NOT DISTINCT FROM`:
   PostgreSQL does not use a B-tree index for `IS DISTINCT FROM`, and `Bool3`
   exists precisely to make that choice visible rather than hide it.

The way out of `Bool3` is the null-safe pair — "compare, and treat null as a
value": `a === b` (`IS NOT DISTINCT FROM`) and `a !== b` (`IS DISTINCT FROM`),
both always `Bool`. Keal's `<==>` is the precedent: "does the order separate
them at all — which is not the question `==` asks". *(Spelling is a
placeholder: two characters, "stricter", the JavaScript baggage means
something else.)*

Why a primitive rather than `Bool?`:

1. **Different connectives.** On `Bool?`, `a and b` would need `?.`. On
   `Bool3`, Keal's eight connectives receive their Kleene (K3) tables —
   well-defined for all eight, `xor` and `implies` included:
   `false and unknown = false`, `true or unknown = true`,
   `unknown and true = unknown`. A `where` clause with no `?.` noise.
2. **Different meaning.** `Bool?` says "maybe not computed". `unknown` says
   "computed, and SQL answers that it cannot know". Conflating them blurs
   what `where` does.

Coercions: `Bool → Bool3` and `Bool? → Bool3` (null ↦ unknown) are free and
implicit. Nothing goes the other way without saying what becomes of
`unknown`.

A `Bool?` *column* stores a value and is declared `Bool?`; `Bool3` is the
type of a *predicate*. A `Bool?` column read in a `where` becomes `Bool3` by
the coercion above. Columns are never declared `Bool3`: that would let
`unknown` into the data.

### No `Comp4`

The argument that justifies `Bool3` — connectives with different semantics —
does not exist for `Comp`. There is no `and` on `Comp`. Its only consumers
are:

* the three-way ternary `a <=> b ? x : y : z` — with `Comp?`, the checker
  forces the null to be handled first (`?:`), machinery Keal already has;
* `orderBy` — where SQL does not say "unknown", it **places** the NULL
  (`NULLS FIRST` / `NULLS LAST`; PostgreSQL puts them last in `ASC`). So
  `orderBy` on a nullable column requires `nullsFirst` or `nullsLast`, and
  that is exactly the operation that turns `Comp?` into `Comp`.

`a <=> b` on a nullable operand answers `Comp?`. A `Comp4` would add a
primitive and buy nothing.

### `enum` ↔ `CREATE TYPE … AS ENUM`

A Keal `enum` declares a PostgreSQL enum type. A `when` over it closes
without `else`; add a variant and every query that forgot it is a compile
error.

### `record` ↔ row

A row *is* a Keal `record`: immutable fields, `==` comparing them one by
one. There is no ORM layer because there is nothing to map.

## 3. Schema

A table reads like a Keal class:

```
table User {
    id:     Id          // ≡ primary id: Serial
    name:   Slug        // ≡ slug name: String
    email:  String?
}

table Post {
    id:      Id
    author:  RefId<User>
    title:   String
    body:    String?
}

table Session {
    primary token: Uuid       // long form: any type may carry the role
    slug    code:  String(8)  // likewise for the slug, with a bounded length
}
```

### Keys

A table has two *roles*, `primary` and `slug`, and two shorthand *types*
that carry them with a default representation:

| Shorthand    | Long form                | Rule                          |
|--------------|--------------------------|-------------------------------|
| `id: Id`     | `primary id: Serial`     | exactly one per table         |
| `name: Slug` | `slug name: String`      | zero or one per table         |

* **Modifiers go before the name**, as everywhere in Keal (`weak var owner`,
  `val`, `var`, `package`, `public`). `id: Uuid primary` would be the only
  postfix modifier in the language; it is not admitted.
* `Id` and `Slug` are types; the field name is free (`key: Id` is legal).
  `id` and `name` are the convention, not a rule.
* **Exactly one primary**, on a single column, whether it comes from `Id` or
  from `primary`. `id: Id` and `primary token: Uuid` in the same table is a
  compile error. Composite primary keys are excluded — a table that wants one
  uses an `Id` plus `unique(a, b)`. This is a door deliberately closed; it is
  what keeps `RefId` total.
* **Zero or one slug**: a `UNIQUE NOT NULL` text column, the table's
  *natural key* — the primary being the surrogate key. Being unique per table
  is what makes `RefSlug<T>` unambiguous without naming a column, and what
  lets the compiler provide a typed, non-nullable `User.bySlug(s)`. A `Slug`
  that were merely an alias for `VARCHAR UNIQUE NOT NULL` would be sugar; the
  one-per-table rule is what makes it a feature. `String(15)` bounds the
  length (`VARCHAR(15)`).
* The long form is for the representation, not for a second key: `Uuid` and
  `BigSerial` are the realistic primaries besides `Serial`; `Bytea` is
  possible.
* **`unique`** is a prefix modifier for any other unique column —
  `unique email: String` — and a table-level `unique(a, b)` for composites.
  `unique` on a column is what `Ref<T.col>` requires to accept it.

### References

Three forms, all ordinary types:

| Form              | Legal when                          | Type of the column |
|-------------------|-------------------------------------|--------------------|
| `RefId<User>`     | `User` declares an `Id` column      | `Int`              |
| `RefSlug<User>`   | `User` declares a `Slug` column     | `String`           |
| `Ref<User.email>` | `email` is `primary`, `slug` or `unique` in `User` | that of the column |

* **`RefId` and `RefSlug` are shorthands for the shorthands.** They are legal
  only when the target used `Id` / `Slug`, so their types are fixed: `Int`
  and `String`, nothing to look up. A table with `primary token: Uuid` or
  `slug code: String(8)` is referenced by the long form, and the error
  message says which: `Ref<Session.token>`.
* **There is no bare `Ref<User>`.** With the two shorthands available it has
  no obvious reading, so it is refused. `Ref<T.col>` always names a column,
  and the compiler refuses one that is not `UNIQUE`.
* Optional references compose with `?`: `RefId<User>?`. No `nullable`
  keyword to invent.
* `post.author.name` in a query is an implicit join. This is where `Ref` as
  a *type* pays back.
* Grammar note: in `Ref<User.email>`, `User.email` in type position is a
  **column reference**, a syntactic category Keal does not have. It gets its
  own production rather than being a special case in the parser.

What the compiler must say about a reference by slug, because it is true:

* **Performance.** A text index instead of an integer one — wider, slower
  joins. The real use case is denormalised reads: the row *carries* the
  readable key, no join to display it. Good when reads are many and joins
  few.
* **Renames.** A `RefSlug` is `ON UPDATE CASCADE`, always: rename the slug
  and the references follow, the only sensible behaviour for a natural key.
  `ON UPDATE` is moot on a `RefId` — a `Serial` never changes.

### On delete

`ON DELETE` is a property of the reference column, so it is a prefix
modifier, one word, like every modifier in Keal:

```
table Post {
    id:       Id
    cascade author:   RefId<User>     // ON DELETE CASCADE
    editor:   RefId<User>?            // ON DELETE SET NULL (default for `?`)
    reviewer: RefId<User>             // ON DELETE RESTRICT (default otherwise)
}
```

| Modifier   | SQL                  | Legal on              |
|------------|----------------------|-----------------------|
| *(none)*   | `RESTRICT`           | `Ref…` — the default  |
| *(none)*   | `SET NULL`           | `Ref…?` — the default |
| `cascade`  | `CASCADE`            | both                  |
| `restrict` | `RESTRICT`           | `Ref…?` — to override its default |
| `setNull`  | `SET NULL`           | `Ref…?` only          |

What nullability buys here, and SQL cannot: `SET NULL` on a `NOT NULL`
column fails in SQL *at run time*, when the `DELETE` happens. In KealSql,
`setNull` on a non-optional reference is a compile error. And on a `Ref…?`
it is the natural default — "the reference is optional and goes away" is
what the `?` already says.

### Declarative schema, not sugared DDL

The gain is not that `primary` is shorter than `PRIMARY KEY`. It is that the
schema is a **source file**, and the tool computes the diff between the file
and the database and generates the migration (the EdgeDB / Atlas / Prisma
model). Without this, KealSql rewrites `CREATE TABLE` with different
parentheses.

**The diff is in v1** — `kealsql --migrate file.kealsql [--db NAME]`:

* The compiler reads the live schema from `pg_catalog` through `psql` (one
  round trip; `PG*` and `~/.pgpass` decide the connection, as for `psql`),
  compares it with the declarations, and prints the migration as SQL to
  review — never applied by the compiler itself. Constraints are matched by
  **shape** (kind, columns, target, actions), never by name, so a database
  built by hand and one built by KealSql diff the same.
* Additive statements are printed as they are: new enum, new value, new
  table, new optional column, widened type (`integer → bigint`,
  `varchar(n) → varchar(m ≥ n)` or `text`), `DROP NOT NULL`, a changed
  reference rule (a drop and an add). **Destructive** ones — `DROP TABLE`,
  `DROP COLUMN`, `DROP TYPE`, a narrowed type, `SET NOT NULL`, a new
  `NOT NULL` column without a default — are **held back as comments**, each
  with what it would cost, until `--destructive` is passed. A value removed
  from an enum is only a note: PostgreSQL cannot drop one.
* **Renames are never inferred** — a dropped `bio` and a new `about` look
  identical to a drop plus an add. The declaration says so, as a prefix in
  the position every modifier has: `renamed(bio) about: String?`, and
  `renamed(Post) table Article { … }`. The migration renames; once the
  database is renamed the annotation is a note ("can go") and nothing else,
  so leaving it in for a while costs nothing.
* The suite applies each test migration in one transaction and runs the
  diff again: it must then print nothing but the notes.
* Out of scope for v1: data migrations (backfills), sequences on a column
  that becomes `Serial`, and anything but PostgreSQL.

## 4. Queries

**`from` comes first.** SQL is written `SELECT … FROM … WHERE` but evaluated
`FROM → WHERE → GROUP → SELECT`. jOOQ keeps SQL's order and pays for it: at
`select(id)` the compiler does not yet know which table `id` belongs to.
PRQL, LINQ and Kysely chose the other way, and so does KealSql:

```
from(User).where(name.like("%ab%")).select(id)
```

This gives type inference, real completion, and composition — adding a
`.where()` to a query received as a parameter.

Mappings:

| Keal                              | SQL                                   |
|-----------------------------------|---------------------------------------|
| `where(p)` with `p: Bool`         | `WHERE p`                             |
| `where(p)` with `p: Bool3`        | `WHERE p` — keeps `true` only; the checker may warn |
| `unless(p)`                       | `WHERE NOT p`                         |
| `when { … }`                      | `CASE WHEN … END`                     |
| `a == null`                       | `a IS NULL` (`Bool`)                  |
| `a === b` / `a !== b`             | `a IS [NOT] DISTINCT FROM b` (`Bool`) |
| `orderBy(c)` with `c` nullable    | requires `nullsFirst` / `nullsLast`   |
| `T?` column                       | nullable column                       |
| `enum`                            | `CREATE TYPE … AS ENUM`               |

## 5. Open questions

* Spelling of the null-safe comparison operators (`===` / `!==` is a
  placeholder).
* `plkeal` with SPI — database access from inside a stored function —
  under the shim discipline of §1; and a runtime entry point for
  initialisation that is not a `static` function called by name.
* PostgreSQL trademark: "KealSql" is fine; "built on PostgreSQL" is the safe
  formula. PostgreSQL's licence (permissive, BSD-like) allows all of this;
  the copyright notice and permission paragraph must be kept.

## 6. Prior art

The idea exists at three levels, and KealSql should read all three.

* **DSL in a host language** — jOOQ (Java; `select(ID).from(T).where(NAME.like(...))`,
  the canonical one), Exposed (Kotlin — closest to Keal's shape), Diesel
  (Rust), SQLAlchemy Core, Slick / Quill, Kysely / Drizzle, Ecto, LINQ.
* **A language compiled to SQL** — PRQL (pipeline, `from` first), Malloy,
  Logica (Datalog → SQL); historically QUEL (Ingres) and Tutorial D.
* **A database that replaces SQL over PostgreSQL** — EdgeDB / Gel (EdgeQL and
  a declarative schema: `required name: str { constraint exclusive }` is
  `Slug`), and Babelfish (AWS: T-SQL as a second front-end on a modified
  engine — proof that the idea ships).

What none of them has: `T?` against `NOT NULL`, a three-valued `Bool3` that
appears only where the types say it must, and a `when` over a database enum
that closes.
