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
for f in tests/cases/*.kealsql; do check "$f" "${f%.kealsql}.sql" 0; done
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
for f in tests/cases/*.sql; do
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
exit $failed
