#!/usr/bin/env sh
# Every tests/cases/NAME.kealsql must compile to exactly tests/cases/NAME.sql,
# and every tests/errors/NAME.kealsql must fail with exactly
# tests/errors/NAME.err (exit 1). `UPDATE=1 tests/run.sh` rewrites the
# expectations from the current output — read the diff before committing it.
#
# When PostgreSQL's `initdb` is on this machine, a private server is started
# in a temporary directory (no root, no configuration, a unix socket) and
# every NAME.sql is loaded into a fresh database with ON_ERROR_STOP; a
# NAME.exec.sql beside it is then run in the same session and its output
# must be exactly NAME.exec.out. Without `initdb` those steps are skipped
# and said so.
cd "$(dirname "$0")/.." || exit 2
# Messages in English and rows in psql's plain form, whatever the machine's
# locale — the expected files were written that way.
export LC_ALL=C
# Windows (Git Bash, MSYS): PostgreSQL has no unix socket there, psql writes
# CRLF, and an extension is a .dll — the server steps run over TCP, outputs
# are normalised, and the library steps are skipped and say so.
WINDOWS=""
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) WINDOWS=1;; esac
[ "${OS:-}" = "Windows_NT" ] && WINDOWS=1
KEAL="${KEAL:-../keal/target/release/keal}"
case "$KEAL" in */*) KEAL="$(cd "$(dirname "$KEAL")" && pwd)/$(basename "$KEAL")";; esac   # build.sh cd's away
[ -f .keal/deps/keal/selfhost/lexing.keal ] || "$KEAL" fetch > /dev/null || { echo "FAIL keal fetch: the lexer comes from the pinned keal"; exit 1; }
failed=0
if python3 -c "pass" > /dev/null 2>&1; then
    python3 ci/band.py --check > /dev/null || { echo "FAIL README.md: the badge band is out of date (python3 ci/band.py)"; failed=1; }
else
    echo "skip README.md band check: no python3 (the Windows Store stub does not count)"
fi
RUN="$KEAL src/main.keal"                # how a case is compiled: the VM, then the native binary
TAG=""                                   # "[native] " on the second pass

check() {
    f="$1"; exp="$2"; want="$3"
    out=$($RUN "$f" 2>&1); code=$?
    out=$(printf '%s' "$out" | tr -d '\r')
    if [ "$code" != "$want" ]; then
        echo "FAIL $TAG$f: exit $code, expected $want"; echo "$out" | head -5; failed=1; return
    fi
    if [ -n "$UPDATE" ] && [ -z "$TAG" ]; then printf '%s\n' "$out" > "$exp"; fi
    if [ ! -f "$exp" ]; then echo "FAIL $f: no $exp (UPDATE=1 to write it)"; failed=1; return; fi
    if printf '%s\n' "$out" | diff -u "$exp" - > /dev/null; then echo "ok   $TAG$f"
    else echo "FAIL $TAG$f"; printf '%s\n' "$out" | diff -u "$exp" - | head -20; failed=1
    fi
}
for f in tests/cases/*.kealsql examples/*.kealsql; do check "$f" "${f%.kealsql}.sql" 0; done
for f in tests/errors/*.kealsql; do check "$f" "${f%.kealsql}.err" 1; done
# `kealsql tokens FILE` must print exactly tests/tokens/NAME.tokens
for f in tests/tokens/*.tokens; do
    [ -f "$f" ] || continue
    name=$(basename "${f%.tokens}"); src=$(ls tests/cases/$name.kealsql tests/plkeal/$name.kealsql 2>/dev/null | head -1)
    out=$($RUN tokens "$src" 2>&1); code=$?
    out=$(printf '%s' "$out" | tr -d '\r')
    if [ -n "$UPDATE" ] && [ -z "$TAG" ]; then printf '%s\n' "$out" > "$f"; fi
    if [ "$code" = 0 ] && printf '%s\n' "$out" | diff -u "$f" - > /dev/null; then echo "ok   $TAG$src tokens"
    else echo "FAIL $TAG$src tokens"; printf '%s\n' "$out" | diff -u "$f" - | head -10; failed=1
    fi
done

# ---- the compiler itself, compiled natively, must answer the same bytes
NATIVE=$(mktemp -d)/kealsql
if "$KEAL" build src/main.keal -o "$NATIVE" > "$NATIVE.log" 2>&1; then
    RUN="$NATIVE"; TAG="[native] "
    for f in tests/cases/*.kealsql examples/*.kealsql; do check "$f" "${f%.kealsql}.sql" 0; done
    for f in tests/errors/*.kealsql; do check "$f" "${f%.kealsql}.err" 1; done
    for f in tests/tokens/*.tokens; do
        [ -f "$f" ] || continue
        name=$(basename "${f%.tokens}"); src=$(ls tests/cases/$name.kealsql tests/plkeal/$name.kealsql 2>/dev/null | head -1)
        out=$($RUN tokens "$src" 2>&1 | tr -d '\r')
        if printf '%s\n' "$out" | diff -u "$f" - > /dev/null; then echo "ok   $TAG$src tokens"; else echo "FAIL $TAG$src tokens"; failed=1; fi
    done
    RUN="$KEAL src/main.keal"; TAG=""
    export KEALSQL="$NATIVE"              # what `import "./x.kealsql"` runs, below
else
    echo "FAIL keal build src/main.keal"; grep -E "error" "$NATIVE.log" | head -5; failed=1
fi

# ---- against a real PostgreSQL
PGBIN=$(command -v initdb > /dev/null && dirname "$(command -v initdb)" || ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)
if [ -z "$PGBIN" ] || [ ! -x "$PGBIN/initdb" ]; then
    echo "skip PostgreSQL: initdb not found; the SQL was compared, not executed"
    exit $failed
fi
PGDIR=$(mktemp -d)
PORT=54329
stop() { "$PGBIN/pg_ctl" -D "$PGDIR/data" stop -m immediate > /dev/null 2>&1; rm -rf "$PGDIR"; }
trap stop EXIT
"$PGBIN/initdb" -D "$PGDIR/data" -A trust -U kealsql --no-locale -E UTF8 > "$PGDIR/initdb.log" 2>&1 || { echo "FAIL initdb"; cat "$PGDIR/initdb.log" | tail -5; exit 1; }
if [ -n "$WINDOWS" ]; then
    PGHOSTV=127.0.0.1
    "$PGBIN/pg_ctl" -D "$PGDIR/data" -o "-p $PORT -h 127.0.0.1" -l "$PGDIR/server.log" -w start > /dev/null 2>&1 || { echo "FAIL pg_ctl start"; tail -5 "$PGDIR/server.log"; exit 1; }
else
    PGHOSTV="$PGDIR"
    "$PGBIN/pg_ctl" -D "$PGDIR/data" -o "-k $PGDIR -p $PORT -h ''" -l "$PGDIR/server.log" -w start > /dev/null 2>&1 || { echo "FAIL pg_ctl start"; tail -5 "$PGDIR/server.log"; exit 1; }
fi
PSQL="$PGBIN/psql -h $PGHOSTV -p $PORT -U kealsql -q -A -v ON_ERROR_STOP=1"
export PGHOST="$PGHOSTV" PGPORT="$PORT" PGUSER=kealsql PATH="$PGBIN:$PATH"
for f in tests/cases/*.sql examples/*.sql; do
    case "$f" in *.exec.sql) continue;; esac
    name=$(basename "${f%.sql}")
    $PSQL -d postgres -c "CREATE DATABASE $name" > /dev/null
    exec_sql="${f%.sql}.exec.sql"; exp="${f%.sql}.exec.out"
    if [ -f "$exec_sql" ]; then
        out=$($PSQL -d "$name" -f "$f" -f "$exec_sql" 2>&1); code=$?
    else
        out=$($PSQL -d "$name" -f "$f" 2>&1); code=$?
    fi
    out=$(printf '%s' "$out" | tr -d '\r')
    if [ "$code" != 0 ]; then echo "FAIL $f on PostgreSQL"; echo "$out" | head -10; failed=1; continue; fi
    if [ -f "$exec_sql" ]; then
        if [ -n "$UPDATE" ]; then printf '%s\n' "$out" > "$exp"; fi
        if [ ! -f "$exp" ]; then echo "FAIL $exec_sql: no $exp (UPDATE=1 to write it)"; failed=1; continue; fi
        if printf '%s\n' "$out" | diff -u "$exp" - > /dev/null; then echo "ok   $f on PostgreSQL, $(basename "$exec_sql") matches"
        else echo "FAIL $exec_sql"; printf '%s\n' "$out" | diff -u "$exp" - | head -20; failed=1
        fi
    else
        echo "ok   $f on PostgreSQL"
    fi
done

# ---- stored functions: tests/plkeal/NAME.kealsql
# NAME.sql is the compiled output (CREATE FUNCTION against $libdir); then the
# library is generated, built against the server headers, loaded with --lib,
# and NAME.exec.sql must print exactly NAME.exec.out.
PGINC=$("$PGBIN/pg_config" --includedir-server 2>/dev/null)
for f in tests/plkeal/*.kealsql; do
    [ -f "$f" ] || continue
    check "$f" "${f%.kealsql}.sql" 0
    name=$(basename "${f%.kealsql}")
    if [ -n "$WINDOWS" ]; then echo "skip $f on PostgreSQL: a Windows extension is a .dll linking postgres.lib, which build.sh does not make yet"; continue; fi
    if [ ! -f "$PGINC/postgres.h" ] || ! command -v cc > /dev/null; then
        echo "skip $f on PostgreSQL: server headers or a C compiler are missing"; continue
    fi
    out="$PGDIR/plkeal/$name"
    if ! "$KEAL" src/main.keal --plkeal "$out" "$f" > /dev/null; then echo "FAIL $f: --plkeal"; failed=1; continue; fi
    if ! KEAL="$KEAL" sh "$out/build.sh" > "$PGDIR/build.log" 2>&1; then
        echo "FAIL $f: the library does not build"; grep -E "error" "$PGDIR/build.log" | head -5; failed=1; continue
    fi
    # The C compiler speaks: a warning in KealSql's own C (the bridges and entry
    # points, named plkeal_ / kealsql_) is a defect, not noise.
    if grep -A1 "warning:" "$PGDIR/build.log" | grep -qE "plkeal_|kealsql_"; then
        echo "FAIL $f: the library's C warns"; grep -A1 "warning:" "$PGDIR/build.log" | grep -E "plkeal_|kealsql_" | head -5; failed=1; continue
    fi
    $PSQL -d postgres -c "CREATE DATABASE plk_$name" > /dev/null
    "$KEAL" src/main.keal --lib "$out/$name.so" "$f" > "$out/$name.sql"
    exp="${f%.kealsql}.exec.out"
    result=$($PSQL -d "plk_$name" -f "$out/$name.sql" -f "${f%.kealsql}.exec.sql" 2>&1); code=$?
    result=$(printf '%s' "$result" | tr -d '\r')
    if [ "$code" != 0 ]; then echo "FAIL $f on PostgreSQL"; echo "$result" | head -10; failed=1; continue; fi
    if [ -n "$UPDATE" ]; then printf '%s\n' "$result" > "$exp"; fi
    if printf '%s\n' "$result" | diff -u "$exp" - > /dev/null 2>&1; then echo "ok   $f builds, loads, and $(basename "${f%.kealsql}.exec.sql") matches"
    else echo "FAIL $exp"; printf '%s\n' "$result" | diff -u "$exp" - | head -20; failed=1
    fi
done

# ---- the client: tests/client/NAME_app.keal over tests/cases/NAME.kealsql
# The app says `import "./NAME.kealsql"`: Keal's loader runs the compiler
# ($KEALSQL, the native binary built above) to write .kealsql/NAME.client.keal,
# the app is built with libpq and run on a fresh database holding NAME.sql
# and NAME_seed.sql; its output must be exactly NAME_app.out.
PGLIBINC=$("$PGBIN/pg_config" --includedir 2>/dev/null)
for app in tests/client/*_app.keal; do
    [ -f "$app" ] || continue
    name=$(basename "${app%_app.keal}")
    if [ -n "$WINDOWS" ]; then echo "skip $app: the client is not built on Windows yet"; continue; fi
    if [ ! -f "$PGLIBINC/libpq-fe.h" ]; then echo "skip $app: libpq headers missing"; continue; fi
    [ -n "${KEALSQL:-}" ] || { echo "skip $app: no native compiler for the import to run"; continue; }
    dir="$PGDIR/client/$name"; mkdir -p "$dir"
    cp "$app" "tests/cases/$name.kealsql" "$dir/"
    if ! "$KEAL" build "$dir/$(basename "$app")" -I"$PGLIBINC" -lpq -o "$dir/app" > "$dir/build.log" 2>&1; then
        echo "FAIL $app: does not build"; grep -E "error" "$dir/build.log" | head -5; failed=1; continue
    fi
    if grep -A1 "warning:" "$dir/build.log" | grep -qE "kc_|kealsql_"; then
        echo "FAIL $app: the client's C warns"; grep -A1 "warning:" "$dir/build.log" | grep -E "kc_|kealsql_" | head -5; failed=1; continue
    fi
    $PSQL -d postgres -c "CREATE DATABASE client_$name" > /dev/null
    $PSQL -d "client_$name" -f "tests/cases/$name.sql" > /dev/null 2>&1
    [ -f "tests/client/${name}_seed.sql" ] && $PSQL -d "client_$name" -f "tests/client/${name}_seed.sql" > /dev/null 2>&1
    out=$(PGDATABASE="client_$name" "$dir/app" 2>&1); code=$?
    out=$(printf '%s' "$out" | tr -d '\r')
    exp="tests/client/${name}_app.out"
    if [ "$code" != 0 ]; then echo "FAIL $app: exit $code"; echo "$out" | head -10; failed=1; continue; fi
    if [ -n "$UPDATE" ]; then printf '%s\n' "$out" > "$exp"; fi
    if printf '%s\n' "$out" | diff -u "$exp" - > /dev/null 2>&1; then echo "ok   $app builds against libpq and matches"
    else echo "FAIL $exp"; printf '%s\n' "$out" | diff -u "$exp" - | head -20; failed=1
    fi
done
[ -n "${NATIVE:-}" ] && rm -rf "$(dirname "$NATIVE")"

# ---- migrations: tests/migrations/NAME/{before,after}.kealsql
# The database is built from before.kealsql; `--migrate after.kealsql` must
# print exactly expected.sql (destructive statements held back), the
# `--destructive` form must apply in one transaction, and a second
# `--migrate` must then print exactly settled.sql — the notes, and nothing
# to do.
# A file with stored functions or triggers needs its library: built here, named by --lib.
# Answers 0 with the library's path, 1 when it does not build, 2 when this
# machine cannot build one — a skip, not a failure.
libfor() {
    if grep -qE '^(stored|trigger) ' "$1"; then
        [ -z "$WINDOWS" ] || return 2
        [ -f "$PGINC/postgres.h" ] || return 2
        dir="$PGDIR/plkeal/$(basename "$(dirname "$1")")_$(basename "${1%.kealsql}")"
        "$KEAL" src/main.keal --plkeal "$dir" "$1" > /dev/null && KEAL="$KEAL" sh "$dir/build.sh" > "$dir/build.log" 2>&1 && echo "$dir/$(basename "${1%.kealsql}").so"
    fi
}
for d in tests/migrations/*/; do
    name="mig_$(basename "$d")"
    $PSQL -d postgres -c "CREATE DATABASE $name" > /dev/null
    blib=$(libfor "$d/before.kealsql"); rc=$?
    [ "$rc" = 2 ] && { echo "skip $d: its library cannot be built on this machine"; continue; }
    [ "$rc" = 0 ] || { echo "FAIL $d: its library does not build"; failed=1; continue; }
    alib=$(libfor "$d/after.kealsql"); rc=$?
    [ "$rc" = 2 ] && { echo "skip $d: its library cannot be built on this machine"; continue; }
    [ "$rc" = 0 ] || { echo "FAIL $d: its library does not build"; failed=1; continue; }
    LIBB=""; [ -n "$blib" ] && LIBB="--lib $blib"
    LIBA=""; [ -n "$alib" ] && LIBA="--lib $alib"
    if ! "$KEAL" src/main.keal $LIBB "$d/before.kealsql" | $PSQL -d "$name" > "$PGDIR/before.log" 2>&1; then
        echo "FAIL $d: before.kealsql does not load"; head -3 "$PGDIR/before.log"; failed=1; continue
    fi
    out=$("$KEAL" src/main.keal --migrate "$d/after.kealsql" --db "$name" $LIBA 2>&1); code=$?
    out=$(printf '%s' "$out" | tr -d '\r' | sed "s|$PGDIR|PGDIR|g")
    if [ "$code" != 0 ]; then echo "FAIL $d: --migrate exit $code"; echo "$out" | head -5; failed=1; continue; fi
    if [ -n "$UPDATE" ]; then printf '%s\n' "$out" > "$d/expected.sql"; fi
    if ! printf '%s\n' "$out" | diff -u "$d/expected.sql" - > /dev/null 2>&1; then
        echo "FAIL $d/expected.sql"; printf '%s\n' "$out" | diff -u "$d/expected.sql" - | head -20; failed=1; continue
    fi
    if ! "$KEAL" src/main.keal --migrate "$d/after.kealsql" --db "$name" $LIBA --destructive | $PSQL -1 -d "$name" > "$PGDIR/apply.log" 2>&1; then
        echo "FAIL $d: the migration does not apply"; head -5 "$PGDIR/apply.log"; failed=1; continue
    fi
    out=$("$KEAL" src/main.keal --migrate "$d/after.kealsql" --db "$name" $LIBA 2>&1)
    out=$(printf '%s' "$out" | tr -d '\r' | sed "s|$PGDIR|PGDIR|g")
    if [ -n "$UPDATE" ]; then printf '%s\n' "$out" > "$d/settled.sql"; fi
    if printf '%s\n' "$out" | diff -u "$d/settled.sql" - > /dev/null 2>&1; then echo "ok   $d migrates, applies, and settles"
    else echo "FAIL $d/settled.sql"; printf '%s\n' "$out" | diff -u "$d/settled.sql" - | head -20; failed=1
    fi
done
exit $failed
