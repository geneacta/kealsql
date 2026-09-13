"""The benchmark page: KealSql against the other ways of talking to
PostgreSQL, and Keal inside the server against its other languages.

The numbers come from `bench/results.txt`, written by `bench/run.sh`; this
file only reads them and says what they mean, in both languages. To add a
machine, run the harness and append its block to results.txt: the page
renders every block it finds.
"""

import html
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEXT = {
    "en": {
        "title": "Benchmark — KealSql",
        "desc": "KealSql measured: the client against psql and raw libpq, and Keal inside PostgreSQL against PL/pgSQL, SQL and C.",
        "h1": "What it costs.",
        "lede": "One PostgreSQL, three questions: does KealSql cost anything on the way to the database, and what does Keal inside the server cost against its neighbours, on arithmetic and on text. Every number is the best of three runs, on the machine named; the procedure is <a href=\"https://github.com/geneacta/kealsql/blob/main/bench/run.sh\">bench/run.sh</a>, and the reading is in <a href=\"https://github.com/geneacta/kealsql/blob/main/bench/README.md\">bench/README.md</a>.",
        "parts": {
            "A": ("On the way to the database", "The same query, 20 000 times on one connection: <code>psql</code> running <code>EXECUTE</code> from a script, the KealSql client — a Keal program over libpq — and a C program over libpq, prepared once or sending the text every time. The three prepared paths are within the run-to-run noise of each other (ten to twenty percent on a virtual machine): the time is the round trip and the server, and the client adds nothing that can be measured. Sending the SQL as text each time costs a quarter more — that is what preparing buys, and what the compiler does for every query."),
            "B": ("Inside the server, on arithmetic", "<code>steps(n)</code>, the Collatz count, over 300 000 rows: the same loop as a Keal <code>stored func</code> — compiled through C into a <code>LANGUAGE C</code> function — in PL/pgSQL, and hand-written in C. Keal is about twenty times faster than PL/pgSQL and about two and a half times slower than the C: the difference is Keal's checked arithmetic and its loop, not the bridge, since an integer crosses as an integer."),
            "C": ("Inside the server, on text", "<code>vowels(s)</code>, a loop over the forty characters of each of 300 000 rows: Keal, PL/pgSQL, the SQL builtin <code>translate()</code>, and C. Keal is four times faster than PL/pgSQL and twenty times slower than C: iterating a string in Keal hands out one small string per character, a cost of the language measured elsewhere too — a loop over characters is where Keal is slowest. And <code>translate()</code> in one SQL expression beats the loop three to one: when a builtin does the job, use the builtin; KealSql exposes them."),
        },
        "floor": "the floor",
        "not_here": "What is not here: another database. KealSql compiles to PostgreSQL and runs on nothing else, so a comparison with MySQL or SQLite would measure those servers, not this compiler.",
        "machine": "Machine",
    },
    "fr": {
        "title": "Benchmark — KealSql",
        "desc": "KealSql mesuré : le client face à psql et à libpq brut, et Keal dans PostgreSQL face à PL/pgSQL, SQL et C.",
        "h1": "Ce que ça coûte.",
        "lede": "Un PostgreSQL, trois questions : KealSql coûte-t-il quelque chose sur le chemin de la base, et que coûte Keal dans le serveur face à ses voisins, sur de l'arithmétique et sur du texte. Chaque nombre est le meilleur de trois exécutions, sur la machine nommée ; la procédure est <a href=\"https://github.com/geneacta/kealsql/blob/main/bench/run.sh\">bench/run.sh</a>, et la lecture dans <a href=\"https://github.com/geneacta/kealsql/blob/main/bench/README.md\">bench/README.md</a>.",
        "parts": {
            "A": ("Sur le chemin de la base", "La même requête, 20 000 fois sur une connexion : <code>psql</code> exécutant des <code>EXECUTE</code> depuis un script, le client KealSql — un programme Keal sur libpq — et un programme C sur libpq, préparé une fois ou envoyant le texte à chaque fois. Les trois chemins préparés sont dans le bruit d'une exécution à l'autre (dix à vingt pour cent sur une machine virtuelle) : le temps est l'aller-retour et le serveur, et le client n'ajoute rien de mesurable. Envoyer le SQL en texte à chaque fois coûte un quart de plus — c'est ce que préparer achète, et ce que le compilateur fait pour chaque requête."),
            "B": ("Dans le serveur, sur de l'arithmétique", "<code>steps(n)</code>, le compte de Collatz, sur 300 000 lignes : la même boucle en <code>stored func</code> Keal — compilée via C en fonction <code>LANGUAGE C</code> — en PL/pgSQL, et écrite à la main en C. Keal est environ vingt fois plus rapide que PL/pgSQL et environ deux fois et demie plus lent que le C : la différence est l'arithmétique vérifiée de Keal et sa boucle, pas le pont, puisqu'un entier traverse comme un entier."),
            "C": ("Dans le serveur, sur du texte", "<code>vowels(s)</code>, une boucle sur les quarante caractères de chacune de 300 000 lignes : Keal, PL/pgSQL, la fonction SQL <code>translate()</code>, et C. Keal est quatre fois plus rapide que PL/pgSQL et vingt fois plus lent que C : itérer une chaîne en Keal rend une petite chaîne par caractère, un coût du langage mesuré ailleurs aussi — une boucle sur des caractères est là où Keal est le plus lent. Et <code>translate()</code> en une expression SQL bat la boucle trois contre un : quand une fonction intégrée fait le travail, prenez-la ; KealSql les expose."),
        },
        "floor": "le plancher",
        "not_here": "Ce qui n'est pas ici : une autre base. KealSql compile vers PostgreSQL et ne tourne sur rien d'autre ; comparer à MySQL ou SQLite mesurerait ces serveurs, pas ce compilateur.",
        "machine": "Machine",
    },
}

LINE = re.compile(r"^\s{2}(.+?):\s+(\d+) ms$")
PART = re.compile(r"^([ABC])\. (.*)$")


def read_results():
    """The blocks of bench/results.txt: one per machine, parts A, B, C."""
    machines = []
    with open(os.path.join(ROOT, "bench", "results.txt"), encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if line.startswith("machine: "):
                machines.append({"name": line[len("machine: "):], "parts": {}})
                continue
            m = PART.match(line)
            if m and machines:
                machines[-1]["parts"][m.group(1)] = {"what": m.group(2), "rows": []}
                current = m.group(1)
                continue
            m = LINE.match(line)
            if m and machines:
                machines[-1]["parts"][current]["rows"].append((m.group(1).strip(), int(m.group(2))))
    return machines


def bars(rows, lang):
    """Rows as bars, the fastest full width, each with its ratio to the fastest."""
    timed = [(n, ms) for n, ms in rows if not n.startswith("(")]
    fastest = min(ms for _, ms in timed)
    out = ['<div class="bars">']
    for name, ms in rows:
        if name.startswith("("):
            out.append('<p class="cap">%s: %d ms</p>' % (html.escape(name.strip("()")), ms))
            continue
        width = 100.0 * fastest / ms
        ratio = ms / fastest
        label = "1×" if ratio < 1.005 else "%.1f×" % ratio
        out.append('<div class="barrow"><span class="bl">%s</span><span class="bar"><div data-w="%.1f%%"></div></span><span class="bv">%s ms · %s</span></div>'
                   % (html.escape(name), width, "{:,}".format(ms).replace(",", " "), label))
    out.append("</div>")
    return "".join(out)


def body(lang):
    t = TEXT[lang]
    parts = ['<section class="band"><h1>%s</h1><p class="lede">%s</p></section>' % (t["h1"], t["lede"])]
    for machine in read_results():
        parts.append('<section class="band"><p class="cap">%s : %s</p></section>' % (t["machine"], html.escape(machine["name"])))
        for key in ("A", "B", "C"):
            part = machine["parts"].get(key)
            if not part:
                continue
            head, text = t["parts"][key]
            parts.append('<section class="band"><h2>%s</h2><p class="lede">%s</p>%s</section>' % (head, text, bars(part["rows"], lang)))
    parts.append('<section class="band"><p class="lede">%s</p></section>' % t["not_here"])
    return "\n".join(parts)
