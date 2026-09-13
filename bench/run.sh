#!/usr/bin/env sh
# The benchmark: KealSql against the other ways of talking to PostgreSQL,
# and Keal inside the server against its other procedural languages — on
# one private PostgreSQL, started here. Prints a block for site/bench.py.
#
#   bench/run.sh            (KEAL=... names the toolchain; kealsql must be on the path or in KEALSQL)
#
# Every timing is the best of three runs, wall-clock, on a quiet machine.
cd "$(dirname "$0")/.." || exit 2
export LC_ALL=C
KEAL="${KEAL:-../keal/target/release/keal}"
case "$KEAL" in */*) KEAL="$(cd "$(dirname "$KEAL")" && pwd)/$(basename "$KEAL")";; esac
PGBIN=$(command -v initdb > /dev/null && dirname "$(command -v initdb)" || ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)
PGINC=$("$PGBIN/pg_config" --includedir-server); PGLIBINC=$("$PGBIN/pg_config" --includedir)
W=$(mktemp -d); PORT=54331
stop() { "$PGBIN/pg_ctl" -D "$W/data" stop -m immediate > /dev/null 2>&1; rm -rf "$W"; }
trap stop EXIT
"$PGBIN/initdb" -D "$W/data" -A trust -U bench --no-locale -E UTF8 > "$W/initdb.log" 2>&1
"$PGBIN/pg_ctl" -D "$W/data" -o "-k $W -p $PORT -h ''" -l "$W/server.log" -w start > /dev/null 2>&1
export PGHOST="$W" PGPORT="$PORT" PGUSER=bench PGDATABASE=bench PATH="$PGBIN:$PATH"
[ -n "${KEALSQL:-}" ] || { "$KEAL" build src/main.keal -o "$W/kealsql" > /dev/null 2>&1; export KEALSQL="$W/kealsql"; }
psql -q -d postgres -c "CREATE DATABASE bench" > /dev/null

# ---- the schema, the library, the other languages
mkdir -p "$W/b"; cp bench/blog.kealsql bench/client_bench.keal "$W/b/"
"$KEALSQL" --plkeal "$W/b/lib" bench/blog.kealsql > /dev/null && KEAL="$KEAL" sh "$W/b/lib/build.sh" > "$W/build.log" 2>&1 || { echo "FAIL: the plkeal library does not build"; cat "$W/build.log" | head; exit 1; }
"$KEALSQL" --lib "$W/b/lib/blog.so" bench/blog.kealsql | psql -q -v ON_ERROR_STOP=1 > /dev/null
cc -shared -fPIC -O2 -std=gnu11 -D_GNU_SOURCE -I"$PGINC" -o "$W/native.so" bench/native.c
psql -q -v ON_ERROR_STOP=1 -f bench/server.sql > /dev/null
psql -q -v ON_ERROR_STOP=1 -c "CREATE FUNCTION steps_c(bigint) RETURNS bigint AS '$W/native.so', 'steps_c' LANGUAGE C STRICT IMMUTABLE;" \
     -c "CREATE FUNCTION vowels_c(text) RETURNS bigint AS '$W/native.so', 'vowels_c' LANGUAGE C STRICT IMMUTABLE;" > /dev/null
# rows: one author with 5 published posts among 20 users and 400 posts
psql -q -v ON_ERROR_STOP=1 -c "INSERT INTO \"user\" (name) SELECT 'u' || g FROM generate_series(1, 19) g; INSERT INTO \"user\" (name) VALUES ('ada');" \
     -c "INSERT INTO post (author, title, status) SELECT 1 + (g % 20), 'post ' || g, CASE WHEN g % 2 = 0 THEN 'Published' ELSE 'Draft' END::status FROM generate_series(1, 400) g;" > /dev/null

# ---- the clients
"$KEAL" build "$W/b/client_bench.keal" -I"$PGLIBINC" -lpq -o "$W/client" > "$W/client.log" 2>&1 || { echo "FAIL: the client does not build"; head "$W/client.log"; exit 1; }
cc -O2 -I"$PGLIBINC" -o "$W/raw" bench/raw.c -lpq
{ for i in $(seq 1 20000); do echo "EXECUTE by_author('ada');"; done; } > "$W/execute.sql"
"$KEALSQL" --queries bench/blog.kealsql --lib "$W/b/lib/blog.so" > "$W/queries.sql"

ms() { # best of three, milliseconds
    best=""
    for i in 1 2 3; do
        s=$(date +%s%N); "$@" > /dev/null 2>&1; e=$(date +%s%N)
        t=$(( (e - s) / 1000000 )); [ -z "$best" ] || [ "$t" -lt "$best" ] && best=$t
    done
    echo "$best"
}
cpu=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | sed "s/.*: //"); [ -n "$cpu" ] || cpu="$(uname -m), $(nproc) cores"
echo "machine: $cpu, $(uname -s), PostgreSQL $(psql -tAc "show server_version"), keal $("$KEAL" version | sed "s/keal //")"
echo "A. 20 000 calls of byAuthor('ada') — 5 rows each, one connection"
echo "  psql EXECUTE, one script:            $(ms psql -q -f "$W/queries.sql" -f "$W/execute.sql") ms"
echo "  KealSql client (Keal, libpq):        $(ms "$W/client") ms"
echo "  C over libpq, prepared:              $(ms "$W/raw" prepared) ms"
echo "  C over libpq, text each time:        $(ms "$W/raw" text) ms"
N=300000
echo "B. steps(n) over $N rows — a loop of integer arithmetic"
echo "  plkeal (Keal, LANGUAGE C):           $(ms psql -qc "SELECT sum(steps(g)) FROM generate_series(1, $N) g") ms"
echo "  PL/pgSQL:                            $(ms psql -qc "SELECT sum(steps_plpgsql(g)) FROM generate_series(1, $N) g") ms"
echo "  C, hand-written:                     $(ms psql -qc "SELECT sum(steps_c(g)) FROM generate_series(1, $N) g") ms"
M=300000
echo "C. vowels(s) over $M rows — a loop over the characters of a 40-character text"
echo "  plkeal (Keal, LANGUAGE C):           $(ms psql -qc "SELECT sum(vowels('the quick brown fox jumps over the lazy dog' || g)) FROM generate_series(1, $M) g") ms"
echo "  PL/pgSQL:                            $(ms psql -qc "SELECT sum(vowels_plpgsql('the quick brown fox jumps over the lazy dog' || g)) FROM generate_series(1, $M) g") ms"
echo "  SQL, translate():                    $(ms psql -qc "SELECT sum(vowels_sql('the quick brown fox jumps over the lazy dog' || g)) FROM generate_series(1, $M) g") ms"
echo "  C, hand-written:                     $(ms psql -qc "SELECT sum(vowels_c('the quick brown fox jumps over the lazy dog' || g)) FROM generate_series(1, $M) g") ms"
echo "  (loop only, no rows)                 $(ms psql -qc "SELECT count(*) FROM generate_series(1, $M) g") ms"
