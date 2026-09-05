#!/usr/bin/env sh
# The vendored lexer is keal/selfhost/lexing.keal plus the KealSql additions.
# This prints the diff; it should show only the header and lines marked
# `kealsql:` (and what they add). Run it after bumping the Keal pin.
KEAL="${KEAL_SRC:-../keal}"
diff -u "$KEAL/selfhost/lexing.keal" src/lexing.keal
