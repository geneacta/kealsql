# The benchmark

`bench/run.sh` starts a private PostgreSQL, builds everything, and prints
one block per machine; `bench/results.txt` holds the blocks the site
shows, and `site/bench.py` renders them. Every number is the best of
three runs, wall-clock, on a quiet machine — and a virtual one, here, so
the round trips of part A move by ten to twenty percent from run to run
while parts B and C hold within a few percent.

Three questions, on one PostgreSQL:

**A. Does KealSql cost anything on the way to the database?** The same
query, 20 000 times on one connection: `psql` running `EXECUTE` from a
script, the KealSql client (a Keal program over libpq), and a C program
over libpq — prepared once, or sending the text every time. The three
prepared paths are within the run-to-run noise of each other: the time
is the round trip and the server, and the client adds nothing that can
be measured. Sending the SQL as text each time costs a quarter more —
that is what preparing buys, and what the compiler does for every query.

**B. What does Keal inside the server cost against its neighbours, on
arithmetic?** `steps(n)`, the Collatz count, over 300 000 rows: the
same loop in Keal (a `stored func`, compiled through C into a `LANGUAGE
C` function), in PL/pgSQL, and hand-written in C. Keal is about twenty
times faster than PL/pgSQL and about two and a half times slower than the
C — the difference is Keal's checked arithmetic and its loop, not the
bridge, since an integer argument crosses as an integer.

**C. And on text?** `vowels(s)`, a loop over the forty characters of each
of 300 000 rows: Keal, PL/pgSQL, the SQL builtin `translate()`, and C.
Keal is four times faster than PL/pgSQL and twenty times slower than C:
in Keal, iterating a string hands out one small string per character,
which is a cost of the language, measured elsewhere too, and the honest
thing to say is that a loop over characters is where Keal is slowest.
`translate()` in one SQL expression beats the Keal loop three to one —
when a builtin does the job, use the builtin; KealSql exposes them.

**D. And on other servers?** The same 20 000 calls on PostgreSQL 18,
MariaDB 11.8 and SQLite 3.46, each from its own C API with the statement
prepared once — the compiler out of the picture, the servers face to
face. PostgreSQL and MariaDB answer over a socket and cost about the
same; SQLite runs inside the calling process, no round trip at all, and
is six times faster: that is what being embedded buys.

**E. And their procedural languages?** The Collatz loop in each server's
own: Keal and PL/pgSQL on PostgreSQL, SQL/PSM on MariaDB, and on SQLite a
C function the program registers, since it has no stored functions.
MariaDB's interpreter is seven times slower than PL/pgSQL; Keal on
PostgreSQL is a hundred and forty times faster than it, and within three
of SQLite's C. The three servers are checked to agree on the sum over
3 000 rows before anything is timed — an earlier run had reported
MariaDB at 15 ms, which was a failed statement measured as a fast one,
and the harness now refuses a command that fails.

The comparison with other servers measures those servers, not this
compiler: KealSql compiles to PostgreSQL and runs on nothing else. It is
here because the question is asked, and because the answer says where
PostgreSQL stands. MariaDB runs as a private instance in a temporary
directory (`mariadb-install-db`, `mariadbd --skip-networking`), SQLite as
a file there; nothing stays installed but the packages.
