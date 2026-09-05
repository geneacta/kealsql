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
KEAL="${KEAL:-../keal/target/release/keal}"
case "$KEAL" in */*) KEAL="$(cd "$(dirname "$KEAL")" && pwd)/$(basename "$KEAL")";; esac   # build.sh cd's away
failed=0

check() {
    f="$1"; exp="$2"; want="$3"
    out=$("$KEAL" src/main.keal "$f" 2>&1); code=$?
    if [ "$code" != "$want" ]; then
        echo "FAIL $f: exit $code, expected $want"; echo "$out" | head -5; failed=1; return
    fi
    if [ -n "$UPDATE" ]; then printf '%s\n' "$out" > "$exp"; fi
    if [ ! -f "$exp" ]; then echo "FAIL $f: no $exp (UPDATE=1 to write it)"; failed=1; return; fi
    if printf '%s\n' "$out" | diff -u "$exp" - > /dev/null; then echo "ok   $f"
    else echo "FAIL $f"; printf '%s\n' "$out" | diff -u "$exp" - | head -20; failed=1
    fi
}
for f in tests/cases/*.kealsql examples/*.kealsql; do check "$f" "${f%.kealsql}.sql" 0; done
for f in tests/errors/*.kealsql; do check "$f" "${f%.kealsql}.err" 1; done

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
"$PGBIN/pg_ctl" -D "$PGDIR/data" -o "-k $PGDIR -p $PORT -h ''" -l "$PGDIR/server.log" -w start > /dev/null 2>&1 || { echo "FAIL pg_ctl start"; tail -5 "$PGDIR/server.log"; exit 1; }
PSQL="$PGBIN/psql -h $PGDIR -p $PORT -U kealsql -q -A -v ON_ERROR_STOP=1"
export PGHOST="$PGDIR" PGPORT="$PORT" PGUSER=kealsql PATH="$PGBIN:$PATH"
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
    if [ ! -f "$PGINC/postgres.h" ] || ! command -v cc > /dev/null; then
        echo "skip $f on PostgreSQL: server headers or a C compiler are missing"; continue
    fi
    out="$PGDIR/plkeal/$name"
    if ! "$KEAL" src/main.keal --plkeal "$out" "$f" > /dev/null; then echo "FAIL $f: --plkeal"; failed=1; continue; fi
    if ! KEAL="$KEAL" sh "$out/build.sh" > "$PGDIR/build.log" 2>&1; then
        echo "FAIL $f: the library does not build"; grep -E "error" "$PGDIR/build.log" | head -5; failed=1; continue
    fi
    $PSQL -d postgres -c "CREATE DATABASE plk_$name" > /dev/null
    "$KEAL" src/main.keal --lib "$out/$name.so" "$f" > "$out/$name.sql"
    exp="${f%.kealsql}.exec.out"
    result=$($PSQL -d "plk_$name" -f "$out/$name.sql" -f "${f%.kealsql}.exec.sql" 2>&1); code=$?
    if [ "$code" != 0 ]; then echo "FAIL $f on PostgreSQL"; echo "$result" | head -10; failed=1; continue; fi
    if [ -n "$UPDATE" ]; then printf '%s\n' "$result" > "$exp"; fi
    if printf '%s\n' "$result" | diff -u "$exp" - > /dev/null 2>&1; then echo "ok   $f builds, loads, and $(basename "${f%.kealsql}.exec.sql") matches"
    else echo "FAIL $exp"; printf '%s\n' "$result" | diff -u "$exp" - | head -20; failed=1
    fi
done

# ---- migrations: tests/migrations/NAME/{before,after}.kealsql
# The database is built from before.kealsql; `--migrate after.kealsql` must
# print exactly expected.sql (destructive statements held back), the
# `--destructive` form must apply in one transaction, and a second
# `--migrate` must then print exactly settled.sql — the notes, and nothing
# to do.
for d in tests/migrations/*/; do
    name="mig_$(basename "$d")"
    $PSQL -d postgres -c "CREATE DATABASE $name" > /dev/null
    if ! "$KEAL" src/main.keal "$d/before.kealsql" | $PSQL -d "$name" > /dev/null 2>&1; then
        echo "FAIL $d: before.kealsql does not load"; failed=1; continue
    fi
    out=$("$KEAL" src/main.keal --migrate "$d/after.kealsql" --db "$name" 2>&1); code=$?
    if [ "$code" != 0 ]; then echo "FAIL $d: --migrate exit $code"; echo "$out" | head -5; failed=1; continue; fi
    if [ -n "$UPDATE" ]; then printf '%s\n' "$out" > "$d/expected.sql"; fi
    if ! printf '%s\n' "$out" | diff -u "$d/expected.sql" - > /dev/null 2>&1; then
        echo "FAIL $d/expected.sql"; printf '%s\n' "$out" | diff -u "$d/expected.sql" - | head -20; failed=1; continue
    fi
    if ! "$KEAL" src/main.keal --migrate "$d/after.kealsql" --db "$name" --destructive | $PSQL -1 -d "$name" > "$PGDIR/apply.log" 2>&1; then
        echo "FAIL $d: the migration does not apply"; head -5 "$PGDIR/apply.log"; failed=1; continue
    fi
    out=$("$KEAL" src/main.keal --migrate "$d/after.kealsql" --db "$name" 2>&1)
    if [ -n "$UPDATE" ]; then printf '%s\n' "$out" > "$d/settled.sql"; fi
    if printf '%s\n' "$out" | diff -u "$d/settled.sql" - > /dev/null 2>&1; then echo "ok   $d migrates, applies, and settles"
    else echo "FAIL $d/settled.sql"; printf '%s\n' "$out" | diff -u "$d/settled.sql" - | head -20; failed=1
    fi
done
exit $failed
