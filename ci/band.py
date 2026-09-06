#!/usr/bin/env python3
"""Keeps the badge band at the top of README.md current.

    python3 ci/band.py            rewrite it
    python3 ci/band.py --check    fail if it would change

Two numbers, both counted here rather than remembered: the version, the
one in `keal.toml` because that is what `keal add` pins, and the share of
this compiler that is Keal — the README's own claim, and one a reader is
entitled to check. The C that runs inside PostgreSQL and libpq lives as
text inside `src/plkeal.keal` and `src/client.keal`; it is counted as C,
not as Keal, because it is. The site generator is Python and the suite
is shell; they count against the share too.

Everything this band counts is in this repository, so it can only go
stale when somebody here changes something — which is exactly when a
gate should speak. `tests/run.sh` runs `--check`.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
START = "<!-- kealsql-band:start -->"
END = "<!-- kealsql-band:end -->"
SHIELD = "https://img.shields.io/badge/%s-%s-blue?style=flat-square&labelColor=2b2b2b"


def read(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as f:
        return f.read()


def version():
    for line in read("keal.toml").splitlines():
        m = re.match(r'\s*version\s*=\s*"([^"]+)"', line)
        if m:
            return m.group(1)
    raise SystemExit("ci/band.py: keal.toml has no version")


def embedded_c(text):
    """The lines inside the triple-quoted C of a generator file."""
    n = 0
    at = 0
    while True:
        i = text.find('"""', at)
        if i < 0:
            return n
        j = text.find('"""', i + 3)
        if j < 0:
            return n
        n += len(text[i + 3:j].splitlines())
        at = j + 3


def lines():
    keal = c = 0
    for name in sorted(os.listdir(os.path.join(ROOT, "src"))):
        if not name.endswith(".keal"):
            continue
        text = read("src/" + name)
        total = len(text.splitlines())
        inner = embedded_c(text) if name in ("plkeal.keal", "client.keal") else 0
        keal += total - inner
        c += inner
    py = sum(len(read("site/" + n).splitlines()) for n in sorted(os.listdir(os.path.join(ROOT, "site"))) if n.endswith(".py"))
    py += len(read("ci/band.py").splitlines())
    sh = len(read("tests/run.sh").splitlines())
    return keal, c, py, sh


def band():
    keal, c, py, sh = lines()
    share = round((keal * 100) / (keal + c + py + sh))
    releases = "https://github.com/geneacta/kealsql/releases"
    files = "https://github.com/geneacta/kealsql/tree/main/src"
    return "\n".join([
        START,
        '<p align="center">',
        '  <a href="%s"><img alt="version" src="%s"></a>' % (releases, SHIELD % ("version", version())),
        '  <a href="%s"><img alt="written in Keal" src="%s"></a>' % (files, SHIELD % ("written%20in%20Keal", "%d%%25" % share)),
        "</p>",
        END,
    ])


def main():
    path = os.path.join(ROOT, "README.md")
    text = read("README.md")
    if START not in text or END not in text:
        raise SystemExit("ci/band.py: README.md has no %s … %s markers" % (START, END))
    before = text[:text.index(START)]
    after = text[text.index(END) + len(END):]
    now = before + band() + after
    if "--check" in sys.argv:
        if now != text:
            print("ci/band.py: the badge band in README.md is out of date.")
            print("  Run python3 ci/band.py and commit what changes.")
            sys.exit(1)
        print("the badge band says what the repository says")
        return
    if now == text:
        print("the badge band was already current")
        return
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(now)
    print("rewrote the badge band in README.md")


if __name__ == "__main__":
    main()
