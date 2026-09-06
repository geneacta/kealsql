#!/usr/bin/env python3
"""Builds the KealSql site, in English and in French.

    python3 site/build.py

Every page is generated: the landing page, the getting-started guide, and
the reference documents converted from the repository's `.md` files.
English lands in `site/`, French in `site/fr/`, and each page links to its
counterpart. The code the guide shows is read from the files the test suite
holds — the blog case, its compiled SQL, its rows, the client application —
so a page cannot say something the suite does not check.

No dependencies, no build step beyond this file: the output is plain HTML
GitHub Pages can serve as it stands. The markdown converter and the page
chrome follow keal/site/build.py, so the two sites read as one.
"""

import html
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "site")
sys.path.insert(0, SITE)
import content as C  # noqa: E402

BASE_URL = "https://geneacta.github.io/kealsql/"
VERSION = "v0.1.0"

# ---- a small markdown converter -----------------------------------------

INLINE_CODE = re.compile(r"`([^`]+)`")
BOLD = re.compile(r"\*\*([^*]+)\*\*")
ITALIC = re.compile(r"(?<![*\w])\*([^*\n]+)\*(?!\*)")
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")

# Repository-relative links the documents make, and the page each one is.
DOC_PAGES = {"DESIGN.md": "design.html", "GRAMMAR.md": "grammar.html", "README.md": "readme.html"}


def slug(text):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s or "section"


def fix_href(href):
    if href.startswith(("http://", "https://", "#", "mailto:")):
        return href
    anchor = ""
    if "#" in href:
        href, anchor = href.split("#", 1)
        anchor = "#" + anchor
    base = os.path.basename(href)
    if base in DOC_PAGES:
        return DOC_PAGES[base] + anchor
    return "https://github.com/geneacta/kealsql/blob/main/" + href.lstrip("./") + anchor


def inline(text):
    out = html.escape(text, quote=False)
    holes = []

    def stash(m):
        holes.append(m.group(1))
        return "\x00%d\x00" % (len(holes) - 1)

    out = INLINE_CODE.sub(stash, out)
    out = BOLD.sub(r"<strong>\1</strong>", out)
    out = ITALIC.sub(r"<em>\1</em>", out)
    out = LINK.sub(lambda m: '<a href="%s">%s</a>' % (fix_href(m.group(2)), m.group(1)), out)
    for i, code in enumerate(holes):
        out = out.replace("\x00%d\x00" % i, "<code>%s</code>" % code)
    return out


def markdown(text):
    """Markdown to HTML, plus the table of contents entries it passes."""
    lines = text.split("\n")
    out, toc = [], []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("```"):
            lang = line[3:].strip()
            body = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                body.append(lines[i])
                i += 1
            i += 1
            cls = " class=\"lang-%s\"" % lang if lang else ""
            out.append('<pre%s><code>%s</code></pre>' % (cls, html.escape("\n".join(body))))
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            level, title = len(m.group(1)), m.group(2).strip()
            anchor = slug(re.sub(r"`", "", title))
            out.append("<h%d id=\"%s\">%s</h%d>" % (level, anchor, inline(title), level))
            if level == 2:
                toc.append((anchor, re.sub(r"`", "", title)))
            i += 1
            continue
        if re.match(r"^---+\s*$", line):
            out.append("<hr>")
            i += 1
            continue
        if line.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|?\s*$", lines[i + 1]):
            head = [c.strip() for c in line.strip().strip("|").split("|")]
            i += 2
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            t = ["<div class=\"tablewrap\"><table><thead><tr>"]
            t += ["<th>%s</th>" % inline(c) for c in head]
            t.append("</tr></thead><tbody>")
            for r in rows:
                t.append("<tr>" + "".join("<td>%s</td>" % inline(c) for c in r) + "</tr>")
            t.append("</tbody></table></div>")
            out.append("".join(t))
            continue
        if re.match(r"^\s*[-*]\s+", line):
            items = []
            while i < len(lines) and (re.match(r"^\s*[-*]\s+", lines[i]) or (lines[i].startswith("  ") and lines[i].strip() and items)):
                if re.match(r"^\s*[-*]\s+", lines[i]):
                    items.append(re.sub(r"^\s*[-*]\s+", "", lines[i]))
                else:
                    items[-1] += " " + lines[i].strip()
                i += 1
            out.append("<ul>" + "".join("<li>%s</li>" % inline(x) for x in items) + "</ul>")
            continue
        if re.match(r"^\s*\d+\.\s+", line):
            items = []
            while i < len(lines) and (re.match(r"^\s*\d+\.\s+", lines[i]) or (lines[i].startswith("   ") and lines[i].strip() and items)):
                if re.match(r"^\s*\d+\.\s+", lines[i]):
                    items.append(re.sub(r"^\s*\d+\.\s+", "", lines[i]))
                else:
                    items[-1] += " " + lines[i].strip()
                i += 1
            out.append("<ol>" + "".join("<li>%s</li>" % inline(x) for x in items) + "</ol>")
            continue
        if line.startswith(">"):
            body = []
            while i < len(lines) and lines[i].startswith(">"):
                body.append(lines[i].lstrip(">").strip())
                i += 1
            out.append("<blockquote>%s</blockquote>" % inline(" ".join(body)))
            continue
        if not line.strip():
            i += 1
            continue
        para = []
        while i < len(lines) and lines[i].strip() and not lines[i].startswith(("#", "```", "|", ">")) \
                and not re.match(r"^\s*[-*]\s+", lines[i]) and not re.match(r"^\s*\d+\.\s+", lines[i]) \
                and not re.match(r"^---+\s*$", lines[i]):
            para.append(lines[i])
            i += 1
        if not para:
            para.append(lines[i])
            i += 1
        out.append("<p>%s</p>" % inline(" ".join(para)))
    return "\n".join(out), toc


# ---- page chrome ---------------------------------------------------------

# The way back to Keal's own site is the `btn-keal` badge on the right, as
# keal-view has it, so the tabs are this site's pages only.
NAV = {
    "en": [("index.html", "Home"), ("start.html", "Getting started"), ("docs.html", "Docs")],
    "fr": [("index.html", "Accueil"), ("start.html", "Premiers pas"), ("docs.html", "Docs")],
}

FOOTER = {
    "en": ("A Keal-shaped language over PostgreSQL. Built by Geneacta.", "Source on GitHub", "Design", "Grammar"),
    "fr": ("Un langage à la forme de Keal sur PostgreSQL. Construit par Geneacta.", "Les sources sur GitHub", "Design", "Grammaire"),
}

SWITCH = {"en": "Français", "fr": "English"}


def page(lang, filename, title, description, body, active=None, sidebar=None, toc=None):
    prefix = "" if lang == "en" else "../"
    nav_links = []
    for href, label in NAV[lang]:
        cls = ' class="tab-active"' if href == active else ""
        nav_links.append('<a href="%s"%s>%s</a>' % (href, cls, label))
    other = ("fr/" + filename) if lang == "en" else ("../" + filename)
    foot = FOOTER[lang]
    aside = ""
    if sidebar:
        items = "".join('<a href="%s"%s>%s</a>' % (h, ' class="on"' if h == filename else "", t) for h, t in sidebar)
        aside = '<div class="dside">%s</div>' % items
    tocbox = ""
    if toc:
        entries = "".join('<a href="#%s">%s</a>' % (a, html.escape(t)) for a, t in toc)
        head = "ON THIS PAGE" if lang == "en" else "SUR CETTE PAGE"
        tocbox = '<div class="dtoc"><div class="h">%s</div><div class="dtoc-items">%s</div></div>' % (head, entries)
    layout = body
    if sidebar or toc:
        layout = '<div class="dgrid">%s<div class="dmain prose">%s</div>%s</div>' % (aside, body, tocbox)
    return """<!doctype html>
<html lang="%(lang)s">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(title)s</title>
<meta name="description" content="%(desc)s">
<link rel="canonical" href="%(canonical)s">
<link rel="alternate" hreflang="en" href="%(alt_en)s">
<link rel="alternate" hreflang="fr" href="%(alt_fr)s">
<link rel="alternate" hreflang="x-default" href="%(alt_en)s">
<meta property="og:type" content="website">
<meta property="og:site_name" content="KealSql">
<meta property="og:locale" content="%(locale)s">
<meta property="og:title" content="%(title)s">
<meta property="og:description" content="%(desc)s">
<meta property="og:url" content="%(canonical)s">
<meta property="og:image" content="%(image)s">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="%(title)s">
<meta name="twitter:description" content="%(desc)s">
<meta name="twitter:image" content="%(image)s">
<link rel="icon" type="image/png" href="%(prefix)sassets/kealsql.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="%(prefix)sstyle.css">
</head>
<body>
<div class="wrap">
<nav class="nav">
  <div class="nav-left">
    <a href="index.html"><img class="nav-logo" src="%(prefix)sassets/kealsql.png" alt="KealSql"></a>
    <div class="nav-links">%(links)s</div>
  </div>
  <div class="nav-right">
    <span class="badge">%(version)s</span>
    <a class="btn-lang" href="%(other)s">%(other_label)s</a>
    <a class="btn-keal" href="%(keal)s">Keal</a>
    <a class="btn-gh" href="https://github.com/geneacta/kealsql">GitHub</a>
  </div>
</nav>
%(body)s
<footer class="foot">
  <div class="foot-l">%(foot0)s</div>
  <div class="foot-r">
    <a href="https://github.com/geneacta/kealsql">%(foot1)s</a>
    <a href="design.html">%(foot2)s</a>
    <a href="grammar.html">%(foot3)s</a>
  </div>
</footer>
</div>
<script src="%(prefix)ssite.js"></script>
</body>
</html>
""" % {
        "lang": lang, "title": html.escape(title), "desc": html.escape(description), "prefix": prefix,
        "canonical": BASE_URL + ("" if lang == "en" else "fr/") + filename,
        "alt_en": BASE_URL + filename, "alt_fr": BASE_URL + "fr/" + filename,
        "locale": "en_GB" if lang == "en" else "fr_FR", "image": BASE_URL + "assets/kealsql.png",
        "links": "".join(nav_links), "version": VERSION, "other": other, "other_label": SWITCH[lang],
        "keal": "https://geneacta.github.io/keal/" + ("" if lang == "en" else "fr/"),
        "body": layout, "foot0": foot[0], "foot1": foot[1], "foot2": foot[2], "foot3": foot[3],
    }


def write(lang, filename, text):
    out_dir = SITE if lang == "en" else os.path.join(SITE, "fr")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, filename)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    return path


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def code_window(title, code, output=None, run_label="Run"):
    out = ['<div class="cwin">', '<div class="cwin-bar"><span class="f">%s</span>' % html.escape(title)]
    if output is not None:
        out.append('<span class="run">▶ %s</span>' % run_label)
    out.append("</div>")
    out.append("<pre>%s</pre>" % html.escape(code))
    if output is not None:
        out.append('<div class="cwin-out"><pre>%s</pre></div>' % html.escape(output))
    out.append("</div>")
    return "".join(out)


# ---- the code the pages show, read from what the suite checks -----------

def between(text, start, end=None):
    """The lines from the one holding `start` up to (not including) the one holding `end`."""
    lines = text.split("\n")
    i = next(k for k, l in enumerate(lines) if start in l)
    if end is None:
        return "\n".join(lines[i:]).rstrip()
    j = next(k for k, l in enumerate(lines) if k > i and end in l)
    return "\n".join(lines[i:j]).rstrip()


def snippets():
    blog = read("tests/cases/blog.kealsql")
    sql = read("tests/cases/blog.sql")
    rows = read("tests/cases/blog.exec.out")
    app = read("tests/client/blog_app.keal")
    app_out = read("tests/client/blog_app.out")
    stored = read("tests/plkeal/text.kealsql")
    triggers = read("tests/plkeal/triggers.kealsql")
    hero = between(blog, "table User", "func drafts")
    editor_sql = between(sql, "-- func editorOf", "-- func drafts")
    return {
        "hero": hero,
        "hero_out": editor_sql.strip(),
        "blog": blog.strip(),
        "compile_sql": between(sql, "CREATE TABLE \"user\"", "-- func drafts").strip(),
        "psql_rows": between(rows, "id|title", "count").strip(),
        "app": app.strip(),
        "app_out": app_out.strip(),
        "stored": between(stored, "// A URL-safe form", "stored pure func fib").strip() + "\n\n" + between(triggers, "trigger normalizeSku", "trigger countUpdates").strip(),
    }


SHELL = {
    "install": "git clone https://github.com/geneacta/kealsql\ncd kealsql\nkeal fetch\ntests/run.sh",
    "compile": "keal src/main.keal blog.kealsql > blog.sql",
    "createdb": "createdb blog\npsql -d blog -f blog.sql",
    "psql": "psql -d blog -f blog.sql\n\nblog=> EXECUTE by_author('ada');\nblog=> EXECUTE editor_of(2);",
    "client_build": "keal build src/main.keal -o kealsql        # once: the compiler the import runs\nexport KEALSQL=$PWD/kealsql\nkeal build app.keal -I$(pg_config --includedir) -lpq -o app\nPGDATABASE=blog ./app",
    "migrate": "keal src/main.keal --migrate blog.kealsql --db blog > migration.sql\ncat migration.sql\npsql -1 -d blog -f migration.sql\nkeal src/main.keal --migrate blog.kealsql --db blog\n# -- nothing to do: the database matches the declaration",
    "stored": "keal src/main.keal --plkeal build/ blog.kealsql\nsh build/build.sh\nkeal src/main.keal --lib $PWD/build/blog.so blog.kealsql | psql -d blog",
}

MIGRATION_EXAMPLE = """ALTER TABLE post RENAME TO article;
ALTER TABLE "user" ADD COLUMN bio text;
-- DESTRUCTIVE, held back (pass --destructive to emit it): every row of `legacy` is lost
-- DROP TABLE legacy;
-- 1 statement held back"""


# ---- the pages -----------------------------------------------------------

def landing(lang, S):
    t = C.LANDING[lang]
    cards = "".join('<div class="card"><h3>%s</h3><p>%s</p></div>' % (h, p) for h, p in t["cards"])
    chips = "".join("<span>%s</span>" % c for c in t["ways_chips"])
    body = """
<section class="hero">
  <div class="pill">%(pill)s</div>
  <h1>%(h1)s</h1>
  <p class="lede">%(sub)s</p>
  <div class="cta">
    <a class="btn-primary" href="start.html">%(cta1)s</a>
    <a class="btn-ghost" href="docs.html">%(cta2)s</a>
  </div>
  %(hero)s
</section>
<section class="cards">%(cards)s</section>
<section class="band">
  <h2>%(ways_h)s</h2>
  <p class="lede">%(ways_p)s</p>
  <div class="chips">%(chips)s</div>
</section>
<section class="band">
  <h2>%(why_h)s</h2>
  <p class="lede">%(why_p)s</p>
</section>
<section class="band">
  <h2>%(start_h)s</h2>
  %(start)s
  <p class="cap"><a href="start.html">%(start_after)s</a></p>
</section>
""" % {
        "pill": t["pill"], "h1": t["h1"], "sub": t["sub"], "cta1": t["cta1"], "cta2": t["cta2"],
        "hero": code_window(t["hero_file"], S["hero"], S["hero_out"], t["hero_out"]),
        "cards": cards, "ways_h": t["ways_h"], "ways_p": t["ways_p"], "chips": chips,
        "why_h": t["why_h"], "why_p": t["why_p"], "start_h": t["start_h"],
        "start": code_window("shell", SHELL["install"] + "\n" + SHELL["compile"] + "\n" + SHELL["createdb"]),
        "start_after": t["start_after"],
    }
    return page(lang, "index.html", t["title"], t["desc"], body, active="index.html")


def start(lang, S):
    t = C.START[lang]
    windows = {
        "install": code_window(t["shell"], SHELL["install"]),
        "blog": code_window("blog.kealsql", S["blog"]),
        "compile": code_window(t["shell"], SHELL["compile"], S["compile_sql"], "blog.sql"),
        "createdb": code_window(t["shell"], SHELL["createdb"]),
        "psql": code_window(t["shell"], SHELL["psql"], S["psql_rows"], "psql"),
        "client": code_window("app.keal", S["app"], S["app_out"], "PGDATABASE=blog ./app") + code_window(t["shell"], SHELL["client_build"]),
        "migrate": code_window(t["shell"], SHELL["migrate"], MIGRATION_EXAMPLE, "migration.sql"),
        "stored": code_window("blog.kealsql", S["stored"]) + code_window(t["shell"], SHELL["stored"]),
    }
    parts = ['<section class="hero"><h1>%s</h1><p class="lede">%s</p></section>' % (t["h1"], t["lede"])]
    toc = []
    for n, (head, before, key, after) in enumerate(t["steps"], 1):
        anchor = slug(head)
        toc.append((anchor, head))
        parts.append('<section class="band" id="%s"><h2>%d. %s</h2>' % (anchor, n, head))
        parts += ["<p class=\"lede\">%s</p>" % p for p in before]
        if key:
            parts.append(windows[key])
        parts += ["<p class=\"lede\">%s</p>" % p for p in after]
        parts.append("</section>")
    return page(lang, "start.html", t["title"], t["desc"], "\n".join(parts), active="start.html")


def docs_index(lang):
    t = C.DOCS[lang]
    cards = "".join('<a class="card" href="%s"><h3>%s</h3><p>%s</p></a>' % (h, n, d) for h, n, d in t["pages"])
    body = '<section class="hero"><h1>%s</h1><p class="lede">%s</p></section><section class="cards">%s</section>' % (t["h1"], t["lede"], cards)
    return page(lang, "docs.html", t["title"], t["desc"], body, active="docs.html")


def doc_page(lang, source, filename, title):
    t = C.DOCS[lang]
    body, toc = markdown(read(source))
    return page(lang, filename, "%s — KealSql" % title, t["desc"], body, active="docs.html", sidebar=t["sidebar"], toc=toc)


def main():
    S = snippets()
    written = []
    for lang in ("en", "fr"):
        written.append(write(lang, "index.html", landing(lang, S)))
        written.append(write(lang, "start.html", start(lang, S)))
        written.append(write(lang, "docs.html", docs_index(lang)))
        for src, fn, title in (("DESIGN.md", "design.html", "Design"), ("GRAMMAR.md", "grammar.html", "Grammar"), ("README.md", "readme.html", "README")):
            written.append(write(lang, fn, doc_page(lang, src, fn, title)))
    # the sitemap and robots, as GitHub Pages wants them
    urls = []
    for lang in ("en", "fr"):
        for fn in ("index.html", "start.html", "docs.html", "design.html", "grammar.html", "readme.html"):
            urls.append(BASE_URL + ("" if lang == "en" else "fr/") + fn)
    with open(os.path.join(SITE, "sitemap.xml"), "w", encoding="utf-8", newline="") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
        f.write("".join("  <url><loc>%s</loc></url>\n" % u for u in urls))
        f.write("</urlset>\n")
    with open(os.path.join(SITE, "robots.txt"), "w", encoding="utf-8", newline="") as f:
        f.write("User-agent: *\nAllow: /\nSitemap: %ssitemap.xml\n" % BASE_URL)
    check_links(written)
    print("%d pages" % len(written))


def check_links(written):
    """Every relative link on every page must land on a file that exists."""
    bad = 0
    for path in written:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        here = os.path.dirname(path)
        for href in re.findall(r'href="([^"#]+)', text):
            if href.startswith(("http://", "https://", "mailto:")):
                continue
            if not os.path.exists(os.path.join(here, href)):
                print("broken link in %s: %s" % (os.path.relpath(path, ROOT), href))
                bad += 1
    if bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
