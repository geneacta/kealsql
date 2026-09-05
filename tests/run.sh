#!/usr/bin/env sh
# Every tests/cases/NAME.kealsql must compile to exactly tests/cases/NAME.sql,
# and every tests/errors/NAME.kealsql must fail with exactly
# tests/errors/NAME.err (exit 1). `UPDATE=1 tests/run.sh` rewrites the
# expectations from the current output — read the diff before committing it.
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
    if [ ! -f "$exp" ]; then echo "FAIL $f: no $exp (UPDATE=1 to write it)"; failed=1; return
    fi
    if printf '%s\n' "$out" | diff -u "$exp" - > /dev/null; then echo "ok   $f"
    else echo "FAIL $f"; printf '%s\n' "$out" | diff -u "$exp" - | head -20; failed=1
    fi
}
for f in tests/cases/*.kealsql; do check "$f" "${f%.kealsql}.sql" 0; done
for f in tests/errors/*.kealsql; do check "$f" "${f%.kealsql}.err" 1; done
exit $failed
