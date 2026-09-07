#!/usr/bin/env python3
"""Re-tints the family stylesheet into KealSql's.

    python3 site/family.py ../keal/site/style.css

The Keal sites share one stylesheet — same variables, components, radii,
breakpoints. Each child changes six things: the accent hue, the shade of
black, the display face, the mark, the hero motif, the dress of the code
blocks. This script takes Keal's file and writes site/style.css with
KealSql's six, so that when the parent's stylesheet moves, ours follows by
running it again rather than by hand.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TOKENS = ''':root {
  --bg: #0E0F16; --panel: #17181F;
  --line: rgba(183,189,255,.12); --line2: rgba(183,189,255,.16);
  --ink: #E9EAF5; --dim: #9A9DB1; --prose: #ADAFC4; --faint: #65677A;
  --accent: #A1A7FF; --accent-h: #ADB4FF; --mint: #CCD2FF;
  --kw: #B1B7FD; --ty: #CCD2FF; --str: #D9C98B; --code: #CED0DE;
  --display: 'Space Grotesk', Sora, sans-serif;
  --motif: linear-gradient(rgba(161,167,255,.06) 1px, transparent 1px),
           linear-gradient(90deg, rgba(161,167,255,.06) 1px, transparent 1px);
  --motif-size: 48px 48px;
}'''

# Every hard-coded mint in the parent, at the same alpha, in periwinkle.
MINTS = {"rgba(140,220,196,": "rgba(183,189,255,", "rgba(169,235,205,": "rgba(204,210,255,", "rgba(53,200,168,": "rgba(161,167,255,"}

SIGN = '''.wordmark::after { content: ""; display: inline-block; width: 7px; height: 7px;
                   margin-left: 7px; vertical-align: 3px;
                   border: 2px solid var(--accent); box-sizing: border-box; }'''

FAMILY = '''
/* ---- KealSql's six ---- */
.hero h1, .duo h2, .gs-head h2, .band h1, .band h2, .doc-head h1, .prose h1 { font-family: var(--display); }
.hero { background-image: var(--motif); background-size: var(--motif-size); }
/* The way back to Keal: its own mint, as the foot of its K, before the word —
   the only green a child site shows, and it says where you come from. */
.btn-keal { font: 600 13px Sora, sans-serif; color: var(--ink);
            border: 1px solid var(--line2); border-radius: 8px; padding: 7px 14px;
            display: inline-flex; align-items: center; gap: 8px; }
.btn-keal::before { content: ""; display: inline-block; width: 10px; height: 5px;
                    border-radius: 99px; background: #35C8A8; }
.btn-keal:hover { border-color: var(--accent); color: var(--accent-h); }
/* Code blocks in two panes: what someone writes, then what PostgreSQL
   receives. The tab bar names both; the second pane is the SQL. */
.cwin-tabs { display: flex; gap: 18px; }
.cwin-tabs .tab { font: 500 12px 'JetBrains Mono', monospace; color: var(--faint); padding-bottom: 6px; }
.cwin-tabs .tab.on { color: var(--ink); border-bottom: 2px solid var(--accent); }
.cwin-sql { border-top: 1px solid var(--line); background: rgba(161,167,255,.05); }
.cwin-sql pre { margin: 0; padding: 14px 22px; font: 13px/1.7 'JetBrains Mono', monospace; color: var(--dim); }
.cwin-sql .kw { color: var(--kw); }
.cwin-sql .cm { color: var(--faint); }
.hero .cwin-sql pre { white-space: pre-wrap; }
.band .cwin { margin: 18px 0; }
.band .lede { margin-bottom: 14px; }
.cards a.card { display: block; }
'''


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: python3 site/family.py path/to/keal/site/style.css")
    with open(sys.argv[1], encoding="utf-8") as f:
        s = f.read()
    head = s.index(":root {")
    s = s[:head] + TOKENS + s[s.index("}", head) + 1:]
    s = s.replace(s[:s.index("\n")], "/* KealSql site — the family stylesheet of the Keal sites, re-tinted by\n   site/family.py: hue 280, periwinkle. Do not edit; edit the parent, or the script. */", 1)
    for a, b in MINTS.items():
        s = s.replace(a, b)
    i = s.index(".wordmark::after {")
    s = s[:i] + SIGN + s[s.index("}", i) + 1:]
    s += FAMILY
    with open(os.path.join(ROOT, "site", "style.css"), "w", encoding="utf-8", newline="\n") as f:
        f.write(s)
    print("site/style.css: %d lines" % s.count("\n"))


if __name__ == "__main__":
    main()
