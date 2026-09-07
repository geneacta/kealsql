"""The site's own words, in both languages.

Everything here is authored (as opposed to converted from the repository's
`.md` files), so it exists twice: once in English, once in French, with
nothing said in one language that is not said in the other. The code the
pages show is read from the repository by build.py, never typed here, so
a page cannot drift from what the suite checks.
"""

LANDING = {
    "en": {
        "title": "KealSql — Keal's shape over PostgreSQL",
        "desc": "A Keal-shaped language over an unmodified PostgreSQL: schema and queries type-checked together, compiled ahead of time to SQL, migrations from a diff, and Keal running inside the server.",
        "pill": "Not a fork — plain SQL for the PostgreSQL you already run",
        "h1": "Keal's shape over PostgreSQL.",
        "sub": "A schema and its queries in one file, in the syntax of Keal, checked against each other: a column the schema does not have, or a null where it forbids one, is a compile error. The output is SQL an unmodified PostgreSQL runs.",
        "cta1": "Create a database →",
        "cta2": "Read the docs",
        "hero_file": "blog.kealsql",
        "hero_out": "what editorOf compiles to",
        "cards": [
            ("Null safety against the schema",
             "<code>String</code> is <code>NOT NULL</code>, <code>String?</code> is nullable, and <code>?.</code> through a reference is a <code>LEFT JOIN</code>. The type of the result says which join happened."),
            ("Three-valued logic, made visible",
             "<code>Bool3</code> appears only when an operand is nullable. The compiler tells you where a <code>==</code> can be <em>unknown</em> — and <code>===</code> treats null as a value."),
            ("Migrations from a diff",
             "The file is the schema. <code>--migrate</code> reads the live catalog and prints what brings it to the file; destructive steps are held back until you say so."),
            ("Keal inside the server",
             "<code>stored func</code> and <code>trigger</code> bodies are Keal, compiled through C into <code>LANGUAGE C</code> functions — the fastest kind PostgreSQL has — calling the file's own queries, typed."),
            ("The same queries from a program",
             "A Keal program imports the <code>.kealsql</code> itself and gets one typed method per query on a libpq connection. The application never writes SQL, and a renamed column stops it compiling."),
        ],
        "ways_h": "One file, three places to run it.",
        "ways_p": "The compiled SQL loads into <code>psql</code> as prepared statements. The client makes them methods in a Keal program. And a stored function calls them from inside the server, through SPI, with the same types in all three.",
        "ways_chips": ["psql", "a Keal program", "inside PostgreSQL"],
        "why_h": "A transpiler, deliberately.",
        "why_p": "Query performance is a property of the SQL emitted and of PostgreSQL's planner, not of the front-end. The SQL is built at compile time, so every query is a constant prepared statement — exactly what a careful hand would write — and the whole ecosystem, from <code>pg_dump</code> to managed hosting, keeps working.",
        "start_h": "Running in a minute.",
        "start_after": "Then the guide: create a database, use it, evolve it →",
    },
    "fr": {
        "title": "KealSql — la forme de Keal sur PostgreSQL",
        "desc": "Un langage à la forme de Keal sur un PostgreSQL non modifié : schéma et requêtes vérifiés ensemble, compilés à l'avance en SQL, migrations par diff, et du Keal qui tourne dans le serveur.",
        "pill": "Pas un fork — du SQL ordinaire pour le PostgreSQL que vous avez déjà",
        "h1": "La forme de Keal sur PostgreSQL.",
        "sub": "Un schéma et ses requêtes dans un même fichier, dans la syntaxe de Keal, vérifiés l'un contre l'autre : une colonne que le schéma n'a pas, ou un null là où il l'interdit, est une erreur de compilation. La sortie est du SQL qu'un PostgreSQL non modifié exécute.",
        "cta1": "Créer une base →",
        "cta2": "Lire les docs",
        "hero_file": "blog.kealsql",
        "hero_out": "ce que editorOf devient",
        "cards": [
            ("La null-safety contre le schéma",
             "<code>String</code> est <code>NOT NULL</code>, <code>String?</code> est nullable, et <code>?.</code> à travers une référence est un <code>LEFT JOIN</code>. Le type du résultat dit quelle jointure a eu lieu."),
            ("La logique ternaire, rendue visible",
             "<code>Bool3</code> n'apparaît que si un opérande est nullable. Le compilateur dit où un <code>==</code> peut valoir <em>unknown</em> — et <code>===</code> traite null comme une valeur."),
            ("Des migrations par diff",
             "Le fichier est le schéma. <code>--migrate</code> lit le catalogue et imprime ce qui amène la base au fichier ; les étapes destructives sont retenues jusqu'à ce que vous le disiez."),
            ("Du Keal dans le serveur",
             "Les corps de <code>stored func</code> et de <code>trigger</code> sont du Keal, compilé via C en fonctions <code>LANGUAGE C</code> — les plus rapides que PostgreSQL connaisse — qui appellent les requêtes du fichier, typées."),
            ("Les mêmes requêtes depuis un programme",
             "Un programme Keal importe le <code>.kealsql</code> lui-même et obtient une méthode typée par requête sur une connexion libpq. L'application n'écrit jamais de SQL, et une colonne renommée l'empêche de compiler."),
        ],
        "ways_h": "Un fichier, trois endroits où l'exécuter.",
        "ways_p": "Le SQL compilé se charge dans <code>psql</code> comme instructions préparées. Le client en fait des méthodes dans un programme Keal. Et une fonction stockée les appelle depuis l'intérieur du serveur, via SPI, avec les mêmes types aux trois endroits.",
        "ways_chips": ["psql", "un programme Keal", "dans PostgreSQL"],
        "why_h": "Un transpileur, délibérément.",
        "why_p": "La performance d'une requête est une propriété du SQL émis et du planificateur de PostgreSQL, pas du front-end. Le SQL est construit à la compilation, donc chaque requête est une instruction préparée constante — exactement ce qu'une main soigneuse écrirait — et tout l'écosystème, de <code>pg_dump</code> à l'hébergement managé, continue de marcher.",
        "start_h": "En route en une minute.",
        "start_after": "Puis le guide : créer une base, l'utiliser, la faire évoluer →",
    },
}

# ---- the guide: create a database and use it -----------------------------
# Each step is (heading, paragraphs before the code, code window key, paragraphs after).
# Code windows are read from the repository by build.py, keyed by name.

START = {
    "en": {
        "title": "Getting started — KealSql",
        "desc": "Create a PostgreSQL database from a .kealsql file, use it from psql and from a Keal program, evolve it with migrations, and run Keal inside the server.",
        "h1": "Create a database, and use it.",
        "lede": "Ten minutes from an empty PostgreSQL to a typed schema, its queries prepared, an application calling them, and a migration when the file changes. Every command here is the one the test suite runs.",
        "steps": [
            ("What you need", [
                "<strong>Keal</strong>, the toolchain — <a href=\"https://geneacta.github.io/keal/\">geneacta.github.io/keal</a> has the three commands; KealSql wants Keal 1.3.0 or later — the release whose loader reads a <code>.kealsql</code> import.",
                "<strong>PostgreSQL 14 or later</strong> with its client tools on the path: <code>psql</code>, <code>createdb</code>, <code>pg_config</code>. The stored functions need the server headers and a C compiler (<code>postgresql-server-dev-NN</code> on Debian and Ubuntu); the client needs <code>libpq</code>'s headers (<code>libpq-dev</code>).",
                "And KealSql itself:",
            ], "install", [
                "<code>keal fetch</code> fetches Keal's own lexer, which KealSql imports from the commit pinned in <code>keal.toml</code>. <code>tests/run.sh</code> runs the suite: if PostgreSQL is on the machine it starts a private server in a temporary directory — no root, no configuration — and runs every case on it.",
            ]),
            ("Write the file", [
                "A <code>.kealsql</code> file holds a schema and the queries that go with it. This is the blog the suite uses:",
            ], "blog", [
                "Three things to notice. <code>Id</code> is a serial primary key and <code>Slug</code> a unique, non-null text — the two keys a table has, each once. <code>RefId&lt;User&gt;</code> is a reference, and <code>RefId&lt;User&gt;?</code> an optional one, which says what happens on delete (<code>SET NULL</code>) and how a path through it reads (<code>?.</code>, a left join). And a query starts at <code>from</code> and ends at <code>select</code>: the evaluation order, so that at <code>select</code> the checker already knows every column.",
            ]),
            ("Compile it", [
                "The compiler prints SQL — the schema as <code>CREATE</code> statements, then one <code>PREPARE</code> per <code>func</code> or <code>proc</code>:",
            ], "compile", [
                "The path through <code>editor?.</code> became a <code>LEFT JOIN</code>, and the declared result <code>String?</code> says a post without an editor answers null rather than vanishing. That is what the checker holds every query to.",
            ]),
            ("Create the database", [
                "<code>createdb</code> makes an empty database; the compiled file makes everything in it:",
            ], "createdb", [
                "The <code>CREATE</code> statements run once and stay. The <code>PREPARE</code> statements live for the session that runs them — <code>psql</code> here — so loading the file in a later session prepares them again, and the <code>CREATE</code>s would then fail on tables that exist. For the first time this is exactly right; afterwards, <code>--migrate</code> below is the way the schema changes, and the client prepares its own statements.",
            ]),
            ("Use it from psql", [
                "In the same <code>psql</code> session, the queries are prepared statements, called by name with their parameters in order:",
            ], "psql", [
                "<code>editor_of(2)</code> answers one row holding null: the post exists, its editor does not — the left join the <code>?.</code> asked for. Names are the file's, in <code>snake_case</code>.",
            ]),
            ("Use it from a program", [
                "A Keal program imports the <code>.kealsql</code> itself. Keal's loader has <code>kealsql</code> write a module beside it — <code>.kealsql/blog.client.keal</code>, regenerated whenever the file is newer — in which every query is a method on a connection, with the same types: rows are records, <code>first()</code> answers a <code>T?</code>, a failing query is an exception with the query's name. Rename a column in the file and the program stops compiling:",
            ], "client", [
                "<code>createBlog(conninfo, dbname)</code> makes the database when it is missing and its schema when it holds none of the tables; <code>connectBlog(conninfo)</code> opens one that exists. The connection string is libpq's; an empty one leaves everything to the <code>PG*</code> environment and <code>~/.pgpass</code>. Build the program against <code>libpq</code>, with <code>kealsql</code> on the path (or named by <code>KEALSQL</code>):",
            ]),
            ("Evolve it", [
                "Change the file — say, a <code>bio: String?</code> on <code>User</code>, and <code>Post</code> renamed to <code>Article</code> — and ask for the difference with the live database:",
            ], "migrate", [
                "The migration is printed for you to read, never applied by the compiler. Additive steps come as they are. Destructive ones — a dropped column, a narrowed type, a new <code>NOT NULL</code> — are held back as comments naming what they would cost, until <code>--destructive</code>. A rename is never guessed: <code>renamed(old)</code> in the file says so, and once the database is renamed the annotation is a note you may leave in place.",
                "Apply it in one transaction, and ask again: the answer must be <em>nothing to do</em>.",
            ]),
            ("Run Keal inside the server", [
                "A <code>stored func</code> is Keal that PostgreSQL runs as a <code>LANGUAGE C</code> function; a <code>trigger</code> is the same on every row written. Their bodies may call the file's queries, typed, through SPI:",
            ], "stored", [
                "<code>--plkeal</code> writes a Keal program and a <code>build.sh</code> that turns it into a shared library against the server headers; the file's SQL then carries the <code>CREATE FUNCTION</code>s, naming the library with <code>--lib</code>:",
            ]),
            ("Where next", [
                "<a href=\"docs.html\">The docs</a>: the design and its reasons, the grammar with what every construct compiles to, and the README's map of the repository. <a href=\"https://github.com/geneacta/kealsql/blob/main/examples/shop.kealsql\">examples/shop.kealsql</a> is a real file — six tables, twenty-odd queries — that the suite compiles, loads and runs on data.",
            ], None, []),
        ],
        "shell": "shell",
    },
    "fr": {
        "title": "Premiers pas — KealSql",
        "desc": "Créer une base PostgreSQL depuis un fichier .kealsql, l'utiliser depuis psql et depuis un programme Keal, la faire évoluer par migration, et exécuter du Keal dans le serveur.",
        "h1": "Créer une base, et l'utiliser.",
        "lede": "Dix minutes d'un PostgreSQL vide à un schéma typé, ses requêtes préparées, une application qui les appelle, et une migration quand le fichier change. Chaque commande ici est celle que la suite de tests exécute.",
        "steps": [
            ("Ce qu'il faut", [
                "<strong>Keal</strong>, le toolchain — <a href=\"https://geneacta.github.io/keal/fr/\">geneacta.github.io/keal</a> donne les trois commandes ; KealSql veut Keal 1.3.0 ou plus récent — la version dont le chargeur lit un import de <code>.kealsql</code>.",
                "<strong>PostgreSQL 14 ou plus</strong> avec ses outils clients sur le chemin : <code>psql</code>, <code>createdb</code>, <code>pg_config</code>. Les fonctions stockées demandent les en-têtes serveur et un compilateur C (<code>postgresql-server-dev-NN</code> sur Debian et Ubuntu) ; le client, les en-têtes de <code>libpq</code> (<code>libpq-dev</code>).",
                "Et KealSql lui-même :",
            ], "install", [
                "<code>keal fetch</code> récupère le lexer de Keal, que KealSql importe depuis le commit épinglé dans <code>keal.toml</code>. <code>tests/run.sh</code> lance la suite : si PostgreSQL est sur la machine, elle démarre un serveur privé dans un répertoire temporaire — sans root, sans configuration — et y exécute chaque cas.",
            ]),
            ("Écrire le fichier", [
                "Un fichier <code>.kealsql</code> tient un schéma et les requêtes qui vont avec. Voici le blog que la suite utilise :",
            ], "blog", [
                "Trois choses à voir. <code>Id</code> est une clé primaire serial et <code>Slug</code> un texte unique non nul — les deux clés d'une table, chacune une fois. <code>RefId&lt;User&gt;</code> est une référence, et <code>RefId&lt;User&gt;?</code> une référence optionnelle, ce qui dit ce qui se passe à la suppression (<code>SET NULL</code>) et comment un chemin à travers elle se lit (<code>?.</code>, une jointure gauche). Et une requête commence à <code>from</code> et finit à <code>select</code> : l'ordre d'évaluation, pour qu'au <code>select</code> le checker connaisse déjà chaque colonne.",
            ]),
            ("Le compiler", [
                "Le compilateur imprime du SQL — le schéma en instructions <code>CREATE</code>, puis un <code>PREPARE</code> par <code>func</code> ou <code>proc</code> :",
            ], "compile", [
                "Le chemin à travers <code>editor?.</code> est devenu un <code>LEFT JOIN</code>, et le résultat déclaré <code>String?</code> dit qu'un billet sans éditeur répond null plutôt que de disparaître. C'est à cela que le checker tient chaque requête.",
            ]),
            ("Créer la base", [
                "<code>createdb</code> fait une base vide ; le fichier compilé y fait tout le reste :",
            ], "createdb", [
                "Les <code>CREATE</code> s'exécutent une fois et restent. Les <code>PREPARE</code> vivent le temps de la session qui les exécute — <code>psql</code> ici — donc charger le fichier dans une session ultérieure les prépare à nouveau, et les <code>CREATE</code> échoueraient alors sur des tables qui existent. Pour la première fois c'est exactement ce qu'il faut ; ensuite, <code>--migrate</code> ci-dessous est la façon dont le schéma change, et le client prépare ses propres instructions.",
            ]),
            ("L'utiliser depuis psql", [
                "Dans la même session <code>psql</code>, les requêtes sont des instructions préparées, appelées par leur nom avec leurs paramètres dans l'ordre :",
            ], "psql", [
                "<code>editor_of(2)</code> répond une ligne qui tient null : le billet existe, son éditeur non — la jointure gauche que le <code>?.</code> demandait. Les noms sont ceux du fichier, en <code>snake_case</code>.",
            ]),
            ("L'utiliser depuis un programme", [
                "Un programme Keal importe le <code>.kealsql</code> lui-même. Le chargeur de Keal fait écrire par <code>kealsql</code> un module à côté — <code>.kealsql/blog.client.keal</code>, régénéré dès que le fichier est plus récent — où chaque requête est une méthode sur une connexion, avec les mêmes types : les lignes sont des records, <code>first()</code> répond un <code>T?</code>, une requête qui échoue est une exception portant le nom de la requête. Renommez une colonne dans le fichier et le programme cesse de compiler :",
            ], "client", [
                "<code>createBlog(conninfo, dbname)</code> crée la base si elle manque et son schéma si elle ne tient aucune des tables ; <code>connectBlog(conninfo)</code> ouvre une base qui existe. La chaîne de connexion est celle de libpq ; vide, elle laisse tout à l'environnement <code>PG*</code> et à <code>~/.pgpass</code>. Compilez le programme contre <code>libpq</code>, avec <code>kealsql</code> sur le chemin (ou nommé par <code>KEALSQL</code>) :",
            ]),
            ("La faire évoluer", [
                "Changez le fichier — disons un <code>bio: String?</code> sur <code>User</code>, et <code>Post</code> renommé en <code>Article</code> — et demandez la différence avec la base vivante :",
            ], "migrate", [
                "La migration est imprimée pour que vous la lisiez, jamais appliquée par le compilateur. Les étapes additives viennent telles quelles. Les destructives — une colonne supprimée, un type rétréci, un nouveau <code>NOT NULL</code> — sont retenues en commentaires qui nomment ce qu'elles coûteraient, jusqu'à <code>--destructive</code>. Un renommage n'est jamais deviné : <code>renamed(old)</code> dans le fichier le dit, et une fois la base renommée l'annotation est une note que vous pouvez laisser.",
                "Appliquez-la en une transaction, et redemandez : la réponse doit être <em>nothing to do</em>.",
            ]),
            ("Exécuter du Keal dans le serveur", [
                "Une <code>stored func</code> est du Keal que PostgreSQL exécute comme fonction <code>LANGUAGE C</code> ; un <code>trigger</code> est la même chose sur chaque ligne écrite. Leurs corps peuvent appeler les requêtes du fichier, typées, via SPI :",
            ], "stored", [
                "<code>--plkeal</code> écrit un programme Keal et un <code>build.sh</code> qui en fait une bibliothèque partagée contre les en-têtes serveur ; le SQL du fichier porte alors les <code>CREATE FUNCTION</code>, en nommant la bibliothèque par <code>--lib</code> :",
            ]),
            ("Et ensuite", [
                "<a href=\"docs.html\">Les docs</a> : le design et ses raisons, la grammaire avec ce que chaque construction compile, et la carte du dépôt du README. <a href=\"https://github.com/geneacta/kealsql/blob/main/examples/shop.kealsql\">examples/shop.kealsql</a> est un vrai fichier — six tables, une vingtaine de requêtes — que la suite compile, charge et exécute sur des données.",
            ], None, []),
        ],
        "shell": "shell",
    },
}

DOCS = {
    "en": {
        "title": "Docs — KealSql",
        "desc": "The design of KealSql and its reasons, the grammar with what every construct compiles to, and the repository's README.",
        "h1": "Docs",
        "lede": "Three documents from the repository, rendered here as they are: the decisions and why, the syntax and what it becomes, and the map. They are written in English.",
        "pages": [("design.html", "Design", "What KealSql is, why a transpiler, Bool3, keys and references, migrations, plkeal, the client, the escape hatch."),
                  ("grammar.html", "Grammar", "The syntax in EBNF, the rules the checker enforces, and the SQL each construct compiles to."),
                  ("readme.html", "README", "Running it, the layout of the repository, and what is covered.")],
        "sidebar": [("docs.html", "Docs"), ("design.html", "Design"), ("grammar.html", "Grammar"), ("readme.html", "README")],
    },
    "fr": {
        "title": "Docs — KealSql",
        "desc": "Le design de KealSql et ses raisons, la grammaire avec ce que chaque construction compile, et le README du dépôt.",
        "h1": "Docs",
        "lede": "Trois documents du dépôt, rendus ici tels quels : les décisions et leurs raisons, la syntaxe et ce qu'elle devient, et la carte. Ils sont écrits en anglais.",
        "pages": [("design.html", "Design", "Ce qu'est KealSql, pourquoi un transpileur, Bool3, clés et références, migrations, plkeal, le client, l'échappatoire."),
                  ("grammar.html", "Grammaire", "La syntaxe en EBNF, les règles que le checker impose, et le SQL que chaque construction compile."),
                  ("readme.html", "README", "Le lancer, la disposition du dépôt, et ce qui est couvert.")],
        "sidebar": [("docs.html", "Docs"), ("design.html", "Design"), ("grammar.html", "Grammaire"), ("readme.html", "README")],
    },
}
