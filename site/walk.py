"""The step-by-step page: from a bare machine to a running KealSql program.

Written for someone who has never built a compiler or run PostgreSQL. Every
step says what to type, what it does, and what the screen should show
before moving on. Both languages say the same thing.

A step is (title, intro paragraphs, code, output or None, after paragraphs).
`code` is shell unless the tuple names a file; `KEY:blog` and `KEY:app`
are read from the repository by build.py.
"""

WALK = {
    "en": {
        "title": "Step by step — KealSql",
        "desc": "From a bare machine to a Keal program talking to a PostgreSQL database it created itself: every command, what it does, and what you should see.",
        "h1": "Step by step.",
        "lede": "From a bare machine to a Keal program talking to a PostgreSQL database it made itself. Every command is given, with what it does and what the screen should show before you go on. Budget half an hour, most of it waiting for compilers.",
        "check": "You should see",
        "shell": "shell",
        "tip": "If it does not",
        "steps": [
            ("Before you start", [
                "You need a terminal and an internet connection. The commands are for Linux (Debian, Ubuntu) and macOS; Windows notes are given where things differ — the compiler, the SQL and the migrations work there under Git Bash, the stored functions and the client do not yet.",
                "Where a command begins with <code>sudo</code>, your machine will ask for your password: that is installing system packages, nothing else.",
            ], None, None, []),
            ("Install Rust", [
                "Keal's compiler is built with Rust's toolchain, and this is the only reason you need it. <code>rustup</code> installs it in your home directory, without root:",
            ], "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh\n. \"$HOME/.cargo/env\"\ncargo --version", "cargo 1.8x.x (…)", [
                "On Windows, download <code>rustup-init.exe</code> from <a href=\"https://rustup.rs\">rustup.rs</a> and choose the <em>GNU</em> toolchain (<code>x86_64-pc-windows-gnu</code>) with MinGW, which is what KealSql was tested with.",
            ]),
            ("Build Keal", [
                "Keal is the language KealSql is written in and compiles to. Clone it, build it, and put the binary on your path. The build takes a minute or two.",
            ], "git clone https://github.com/geneacta/keal\ncd keal\ncargo build --release\nexport PATH=\"$PWD/target/release:$PATH\"\nkeal version\ncd ..", "keal 1.2.0", [
                "The <code>export PATH</code> line lasts for this terminal only; add it to your shell's startup file (<code>~/.bashrc</code>, <code>~/.zshrc</code>) to keep it. <code>cargo install --path .</code> inside <code>keal/</code> is the permanent alternative.",
                "KealSql needs a Keal newer than the 1.2.0 release — commit <code>58f059a</code> or later, which is what <code>main</code> is.",
            ]),
            ("Install PostgreSQL", [
                "The database itself, its client tools, and — for the stored functions and the client — its development headers.",
            ], "# Debian, Ubuntu\nsudo apt install postgresql postgresql-server-dev-all libpq-dev\n\n# macOS with Homebrew\nbrew install postgresql@17\nbrew services start postgresql@17\n\npsql --version\npg_config --includedir", "psql (PostgreSQL) 17.x\n/usr/include/postgresql", [
                "On Windows, the <a href=\"https://www.enterprisedb.com/downloads/postgres-postgresql-downloads\">EDB installer</a> gives you <code>psql</code>, <code>createdb</code> and <code>pg_config</code>; add its <code>bin</code> directory to the path.",
            ]),
            ("Give yourself a database user", [
                "PostgreSQL has its own users. On Linux the server is installed with one, <code>postgres</code>, that only the system user of the same name may become; the simplest thing is to make a PostgreSQL user with your own login name, so that <code>psql</code> connects without asking anything:",
            ], "sudo -u postgres createuser --superuser \"$USER\"\npsql -d postgres -c 'select current_user'", " current_user\n--------------\n renard\n(1 row)", [
                "On macOS with Homebrew the server already knows your user; skip the first line. On Windows, the installer asked you for the <code>postgres</code> password: set <code>PGUSER=postgres</code> and <code>PGPASSWORD=…</code> in the environment, or write them in <code>%APPDATA%\\postgresql\\pgpass.conf</code>.",
                "<strong>If it does not:</strong> <em>peer authentication failed</em> means the PostgreSQL user does not exist yet — the first line failed, read its message. <em>connection refused</em> means the server is not running: <code>sudo systemctl start postgresql</code> on Linux.",
            ]),
            ("Get KealSql", [
                "Clone it, fetch the piece of Keal it imports (its lexer, pinned to a commit), and build the compiler into a binary called <code>kealsql</code>. Keal's loader will look for that binary by name when a program imports a <code>.kealsql</code> file.",
            ], "git clone https://github.com/geneacta/kealsql\ncd kealsql\nkeal fetch\nkeal build src/main.keal -o kealsql\nexport PATH=\"$PWD:$PATH\"\nkealsql tests/cases/blog.kealsql | head -5\ncd ..", "CREATE TABLE \"user\" (\n    id serial PRIMARY KEY,\n    name text UNIQUE NOT NULL,\n    email text UNIQUE NOT NULL,\n    bio text", [
                "Until the binary is on the path, <code>keal src/main.keal file.kealsql</code> does the same thing on Keal's VM, and <code>export KEALSQL=/path/to/kealsql</code> tells the loader where it is.",
                "<strong>Optional but reassuring:</strong> <code>tests/run.sh</code> runs the whole suite. With PostgreSQL installed it starts a private server in a temporary directory and runs every case on it; the last lines should be <code>ok</code> and <code>skip</code>, never <code>FAIL</code>.",
            ]),
            ("Write your first file", [
                "Make a directory for the project and write the schema and its queries. This is the blog the suite uses; read the notes under it.",
            ], "mkdir myblog\ncd myblog\n# then create blog.kealsql with the content below", None, []),
            ("The file, explained", [], "KEY:blog", None, [
                "<code>enum Status</code> becomes a PostgreSQL enum type. <code>table User { … }</code> becomes a table: <code>id: Id</code> is a serial primary key, <code>name: Slug</code> a unique text — every table has one primary and at most one slug. <code>String?</code> is a column that may be null; <code>String</code> may not.",
                "<code>cascade author: RefId&lt;User&gt;</code> is a foreign key to <code>User</code>'s primary, deleted along with the user; <code>editor: RefId&lt;User&gt;?</code> is an optional one, set to null when the user goes.",
                "A <code>func</code> is a query with a name, parameters and a declared result. It reads from <code>from</code> to <code>select</code>, in the order the database evaluates it. <code>p.author.name</code> walks the reference — a join the compiler writes. <code>editor?.name</code> walks an optional one — a <em>left</em> join, and the result is <code>String?</code>. A <code>proc</code> is a change that answers nothing.",
            ]),
            ("Compile it", [
                "The compiler turns the file into SQL: the tables as <code>CREATE</code> statements, then one prepared statement per query. Look at the file it wrote; it is plain SQL you could have typed.",
            ], "kealsql blog.kealsql > blog.sql\ngrep -c PREPARE blog.sql\ngrep -A5 'func editorOf' blog.sql", "5\n-- func editorOf(post: Int): String?\nPREPARE editor_of(integer) AS\nSELECT editor.name\nFROM post\nLEFT JOIN \"user\" AS editor ON post.editor = editor.id\nWHERE post.id = $1", [
                "<strong>If it does not:</strong> an <code>error blog.kealsql:L:C …</code> line names the place and says what to write. The most common one for a first file is a column named in a query that the table does not have.",
            ]),
            ("Create the database", [
                "<code>createdb</code> makes an empty database named <code>blog</code>; loading the compiled file into it makes the tables. Then look at them.",
            ], "createdb blog\npsql -d blog -f blog.sql\npsql -d blog -c '\\dt'", "         List of tables\n Schema | Name | Type  |  Owner\n--------+------+-------+--------\n public | post | table | you\n public | user | table | you\n(2 rows)", [
                "The <code>CREATE</code> statements are permanent. The <code>PREPARE</code> statements are not: they live for the <code>psql</code> session that ran them. That is why the next step loads them again, with <code>--queries</code>, in the session that uses them — and why a program (step 12) prepares its own.",
            ]),
            ("Put some rows in, and query them", [
                "One <code>psql</code> session: load the queries — <code>--queries</code> prints the <code>PREPARE</code>s without the <code>CREATE</code>s, which would fail on tables that exist — insert two users and three posts, and call the queries by name. <code>EXECUTE</code> is how a prepared statement is called; the names are the file's, in <code>snake_case</code>.",
            ], "kealsql --queries blog.kealsql > queries.sql\npsql -d blog\n\nblog=> \\i queries.sql\nblog=> INSERT INTO \"user\" (name, email) VALUES ('ada', 'ada@x'), ('bob', 'bob@x');\nblog=> INSERT INTO post (author, editor, title, status, created) VALUES\n         (1, 2, 'Hello', 'Published', now()),\n         (1, NULL, 'Draft one', 'Draft', now()),\n         (2, NULL, 'Bob post', 'Published', now());\nblog=> EXECUTE by_author('ada');\nblog=> EXECUTE editor_of(2);\nblog=> EXECUTE drafts;\nblog=> \\q", " id | title\n----+-------\n  1 | Hello\n(1 row)\n\n name\n------\n\n(1 row)\n\n count\n-------\n     1\n(1 row)", [
                "<code>editor_of(2)</code> answers one row holding nothing: post 2 exists and has no editor. That is the left join the <code>?.</code> in the file asked for. <code>by_author('ada')</code> answers one post, not two: the file says <code>status == Published</code>, and Ada's second post is a draft.",
            ]),
            ("Write a Keal program that uses it", [
                "Now the same queries from a program. A Keal program imports the <code>.kealsql</code> file itself; Keal's loader runs <code>kealsql</code> to write a module beside it, <code>.kealsql/blog.client.keal</code>, in which every query is a method on a connection. Write <code>app.keal</code> next to <code>blog.kealsql</code>:",
            ], ("app.keal", "import \"./blog.kealsql\"\n\n// The database and its tables, made if they are missing; a connection to them.\nval db = createBlog(\"\", \"blog\")\n\nprintln(\"drafts: ${db.drafts()}\")\nfor (p in db.byAuthor(\"ada\")) {\n    println(\"#${p.id} ${p.title}\")\n}\nval editor = db.editorOf(1)\nprintln(\"editor of #1: ${editor ?: \"none\"}\")\ndb.close()"), None, [
                "<code>createBlog(\"\", \"blog\")</code>: the first argument is a libpq connection string — empty, it uses the same defaults as <code>psql</code> (your user, the local server); the second is the database's name, made if it does not exist. Here it exists, with rows, so the call only connects.",
                "<code>db.byAuthor(\"ada\")</code> answers a list of records with <code>id</code> and <code>title</code>; <code>db.editorOf(1)</code> answers a <code>String?</code>, which is why <code>?: \"none\"</code> is there.",
            ]),
            ("Build and run it", [
                "The program links against <code>libpq</code>, PostgreSQL's client library; the two flags say where its header and its library are.",
            ], "keal build app.keal -I$(pg_config --includedir) -lpq -o app\n./app\nls .kealsql", "drafts: 1\n#1 Hello\neditor of #1: bob\nblog.client.keal", [
                "The <code>.kealsql/</code> directory holds the generated module. Commit it with the project: a checkout then builds without <code>kealsql</code> installed, and Keal regenerates it whenever <code>blog.kealsql</code> is newer.",
                "<strong>If it does not:</strong> <em>cannot generate … `kealsql` is not installed</em> — the binary of step 6 is not on the path; <code>export KEALSQL=/path/to/kealsql</code>. <em>libpq-fe.h: No such file</em> — install <code>libpq-dev</code> (Linux) and check <code>pg_config --includedir</code>. <em>connection refused</em> or <em>authentication failed</em> — step 5.",
            ]),
            ("Change the file, and let the compiler catch you", [
                "Rename the query <code>drafts</code> to <code>draftCount</code> in <code>blog.kealsql</code> and build the program again, without touching it:",
            ], "sed -i 's/func drafts()/func draftCount()/' blog.kealsql\nkeal build app.keal -I$(pg_config --includedir) -lpq -o app", "error: `BlogDb` has no method `drafts`\n  --> app.keal:6:23", [
                "The loader saw that the file was newer, regenerated the module, and the program stopped compiling at the line that used the old name. That is the point of the whole thing: a query the file no longer has is an error in the program, not a failure at run time. Put <code>drafts</code> back, or fix the program.",
            ]),
            ("Evolve the schema", [
                "Add a column to the file — <code>bio: String?</code> is already there; add <code>joined: Date?</code> under it in <code>User</code> — and ask what the live database is missing:",
            ], "kealsql --migrate blog.kealsql --db blog", "ALTER TABLE \"user\" ADD COLUMN joined date;", [
                "Nothing was applied: the migration is printed for you to read. Apply it in one transaction and ask again — the answer must be <em>nothing to do</em>:",
            ]),
            ("Apply the migration", [], "kealsql --migrate blog.kealsql --db blog > migration.sql\npsql -1 -d blog -f migration.sql\nkealsql --migrate blog.kealsql --db blog", "-- nothing to do: the database matches the declaration", [
                "A dropped column, a narrowed type or a new <code>NOT NULL</code> would be printed as comments, held back until you pass <code>--destructive</code> — the compiler names what they would cost. A rename is never guessed: write <code>renamed(oldName) newName: Type</code> in the file, and the migration renames.",
            ]),
            ("Keal inside the server (Linux and macOS)", [
                "A <code>stored func</code> is Keal that PostgreSQL runs as a native function. Add one to <code>blog.kealsql</code> and use it in a query:",
            ], ("blog.kealsql (added)", "stored pure func shout(s: String): String { s.toUpper() + \"!\" }\n\nfunc shouted(): List<String> {\n    from(Post).orderBy(id).select(shout(title))\n}"), None, [
                "Then generate the library's source, build it against the server headers, and load the functions with the library's path — <code>--queries</code>, because the tables exist:",
            ]),
            ("Build and load the library", [], "kealsql --plkeal build/ blog.kealsql\nsh build/build.sh\nkealsql --lib \"$PWD/build/blog.so\" --queries blog.kealsql | psql -d blog\npsql -d blog -c \"SELECT shout('hello')\"", " shout\n--------\n HELLO!\n(1 row)", [
                "<strong>If it does not:</strong> <em>postgres.h: No such file</em> — the server headers are missing: <code>postgresql-server-dev-all</code> on Debian and Ubuntu. On Windows this step is not available yet.",
            ]),
            ("Where next", [
                "<a href=\"start.html\">Getting started</a> is the same journey in five minutes; <a href=\"docs.html\">the docs</a> hold the design, the grammar with what every construct compiles to, and the README. <a href=\"https://github.com/geneacta/kealsql/blob/main/examples/shop.kealsql\">examples/shop.kealsql</a> is a bigger real file to read next.",
            ], None, None, []),
        ],
    },
    "fr": {
        "title": "Pas à pas — KealSql",
        "desc": "D'une machine nue à un programme Keal qui parle à une base PostgreSQL qu'il a créée lui-même : chaque commande, ce qu'elle fait, et ce que vous devez voir.",
        "h1": "Pas à pas.",
        "lede": "D'une machine nue à un programme Keal qui parle à une base PostgreSQL qu'il a créée lui-même. Chaque commande est donnée, avec ce qu'elle fait et ce que l'écran doit montrer avant de continuer. Comptez une demi-heure, surtout à attendre des compilateurs.",
        "check": "Vous devez voir",
        "shell": "shell",
        "tip": "Si ça ne marche pas",
        "steps": [
            ("Avant de commencer", [
                "Il faut un terminal et une connexion internet. Les commandes sont celles de Linux (Debian, Ubuntu) et macOS ; des notes Windows sont données là où ça diffère — le compilateur, le SQL et les migrations y marchent sous Git Bash, les fonctions stockées et le client pas encore.",
                "Quand une commande commence par <code>sudo</code>, la machine demandera votre mot de passe : c'est pour installer des paquets système, rien d'autre.",
            ], None, None, []),
            ("Installer Rust", [
                "Le compilateur de Keal se construit avec l'outillage de Rust, et c'est la seule raison d'en avoir besoin. <code>rustup</code> l'installe dans votre répertoire personnel, sans root :",
            ], "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh\n. \"$HOME/.cargo/env\"\ncargo --version", "cargo 1.8x.x (…)", [
                "Sous Windows, téléchargez <code>rustup-init.exe</code> sur <a href=\"https://rustup.rs\">rustup.rs</a> et choisissez l'outillage <em>GNU</em> (<code>x86_64-pc-windows-gnu</code>) avec MinGW : c'est celui avec lequel KealSql a été testé.",
            ]),
            ("Construire Keal", [
                "Keal est le langage dans lequel KealSql est écrit et vers lequel il compile. Clonez-le, construisez-le, et mettez le binaire sur votre chemin. La construction prend une ou deux minutes.",
            ], "git clone https://github.com/geneacta/keal\ncd keal\ncargo build --release\nexport PATH=\"$PWD/target/release:$PATH\"\nkeal version\ncd ..", "keal 1.2.0", [
                "La ligne <code>export PATH</code> ne vaut que pour ce terminal ; ajoutez-la au fichier de démarrage de votre shell (<code>~/.bashrc</code>, <code>~/.zshrc</code>) pour la garder. <code>cargo install --path .</code> dans <code>keal/</code> est l'alternative permanente.",
                "KealSql veut un Keal plus récent que la version 1.2.0 — le commit <code>58f059a</code> ou après, ce qu'est <code>main</code>.",
            ]),
            ("Installer PostgreSQL", [
                "La base elle-même, ses outils clients, et — pour les fonctions stockées et le client — ses en-têtes de développement.",
            ], "# Debian, Ubuntu\nsudo apt install postgresql postgresql-server-dev-all libpq-dev\n\n# macOS avec Homebrew\nbrew install postgresql@17\nbrew services start postgresql@17\n\npsql --version\npg_config --includedir", "psql (PostgreSQL) 17.x\n/usr/include/postgresql", [
                "Sous Windows, l'<a href=\"https://www.enterprisedb.com/downloads/postgres-postgresql-downloads\">installeur EDB</a> donne <code>psql</code>, <code>createdb</code> et <code>pg_config</code> ; ajoutez son répertoire <code>bin</code> au chemin.",
            ]),
            ("Se donner un utilisateur de base", [
                "PostgreSQL a ses propres utilisateurs. Sous Linux le serveur est installé avec un seul, <code>postgres</code>, que seul l'utilisateur système du même nom peut devenir ; le plus simple est de créer un utilisateur PostgreSQL à votre nom de login, pour que <code>psql</code> se connecte sans rien demander :",
            ], "sudo -u postgres createuser --superuser \"$USER\"\npsql -d postgres -c 'select current_user'", " current_user\n--------------\n renard\n(1 row)", [
                "Sous macOS avec Homebrew, le serveur connaît déjà votre utilisateur ; sautez la première ligne. Sous Windows, l'installeur vous a demandé le mot de passe de <code>postgres</code> : posez <code>PGUSER=postgres</code> et <code>PGPASSWORD=…</code> dans l'environnement, ou écrivez-les dans <code>%APPDATA%\\postgresql\\pgpass.conf</code>.",
                "<strong>Si ça ne marche pas :</strong> <em>peer authentication failed</em> veut dire que l'utilisateur PostgreSQL n'existe pas encore — la première ligne a échoué, lisez son message. <em>connection refused</em> veut dire que le serveur ne tourne pas : <code>sudo systemctl start postgresql</code> sous Linux.",
            ]),
            ("Récupérer KealSql", [
                "Clonez-le, récupérez le morceau de Keal qu'il importe (son lexer, épinglé sur un commit), et construisez le compilateur en un binaire nommé <code>kealsql</code>. Le chargeur de Keal cherchera ce binaire par son nom quand un programme importera un fichier <code>.kealsql</code>.",
            ], "git clone https://github.com/geneacta/kealsql\ncd kealsql\nkeal fetch\nkeal build src/main.keal -o kealsql\nexport PATH=\"$PWD:$PATH\"\nkealsql tests/cases/blog.kealsql | head -5\ncd ..", "CREATE TABLE \"user\" (\n    id serial PRIMARY KEY,\n    name text UNIQUE NOT NULL,\n    email text UNIQUE NOT NULL,\n    bio text", [
                "Tant que le binaire n'est pas sur le chemin, <code>keal src/main.keal fichier.kealsql</code> fait la même chose sur la VM de Keal, et <code>export KEALSQL=/chemin/vers/kealsql</code> dit au chargeur où il est.",
                "<strong>Facultatif mais rassurant :</strong> <code>tests/run.sh</code> lance toute la suite. Avec PostgreSQL installé, elle démarre un serveur privé dans un répertoire temporaire et y exécute chaque cas ; les dernières lignes doivent être des <code>ok</code> et des <code>skip</code>, jamais un <code>FAIL</code>.",
            ]),
            ("Écrire votre premier fichier", [
                "Faites un répertoire pour le projet et écrivez le schéma et ses requêtes. C'est le blog que la suite utilise ; lisez les notes dessous.",
            ], "mkdir monblog\ncd monblog\n# puis créez blog.kealsql avec le contenu ci-dessous", None, []),
            ("Le fichier, expliqué", [], "KEY:blog", None, [
                "<code>enum Status</code> devient un type enum PostgreSQL. <code>table User { … }</code> devient une table : <code>id: Id</code> est une clé primaire serial, <code>name: Slug</code> un texte unique — chaque table a un primary et au plus un slug. <code>String?</code> est une colonne qui peut être nulle ; <code>String</code> ne peut pas.",
                "<code>cascade author: RefId&lt;User&gt;</code> est une clé étrangère vers le primary de <code>User</code>, supprimée avec l'utilisateur ; <code>editor: RefId&lt;User&gt;?</code> en est une optionnelle, mise à null quand l'utilisateur disparaît.",
                "Une <code>func</code> est une requête avec un nom, des paramètres et un résultat déclaré. Elle se lit de <code>from</code> à <code>select</code>, dans l'ordre où la base l'évalue. <code>p.author.name</code> suit la référence — une jointure que le compilateur écrit. <code>editor?.name</code> en suit une optionnelle — une jointure <em>gauche</em>, et le résultat est <code>String?</code>. Un <code>proc</code> est une modification qui ne répond rien.",
            ]),
            ("Le compiler", [
                "Le compilateur transforme le fichier en SQL : les tables en instructions <code>CREATE</code>, puis une instruction préparée par requête. Regardez le fichier écrit ; c'est du SQL ordinaire que vous auriez pu taper.",
            ], "kealsql blog.kealsql > blog.sql\ngrep -c PREPARE blog.sql\ngrep -A5 'func editorOf' blog.sql", "5\n-- func editorOf(post: Int): String?\nPREPARE editor_of(integer) AS\nSELECT editor.name\nFROM post\nLEFT JOIN \"user\" AS editor ON post.editor = editor.id\nWHERE post.id = $1", [
                "<strong>Si ça ne marche pas :</strong> une ligne <code>error blog.kealsql:L:C …</code> nomme l'endroit et dit quoi écrire. La plus fréquente sur un premier fichier : une colonne nommée dans une requête que la table n'a pas.",
            ]),
            ("Créer la base", [
                "<code>createdb</code> fait une base vide nommée <code>blog</code> ; y charger le fichier compilé fait les tables. Puis regardez-les.",
            ], "createdb blog\npsql -d blog -f blog.sql\npsql -d blog -c '\\dt'", "         List of tables\n Schema | Name | Type  |  Owner\n--------+------+-------+--------\n public | post | table | you\n public | user | table | you\n(2 rows)", [
                "Les instructions <code>CREATE</code> sont permanentes. Les <code>PREPARE</code> ne le sont pas : elles vivent le temps de la session <code>psql</code> qui les a exécutées. C'est pourquoi l'étape suivante les recharge, avec <code>--queries</code>, dans la session qui s'en sert — et pourquoi un programme (étape 12) prépare les siennes.",
            ]),
            ("Mettre des lignes, et les interroger", [
                "Une session <code>psql</code> : charger les requêtes — <code>--queries</code> imprime les <code>PREPARE</code> sans les <code>CREATE</code>, qui échoueraient sur des tables qui existent — insérer deux utilisateurs et trois billets, et appeler les requêtes par leur nom. <code>EXECUTE</code> est la façon d'appeler une instruction préparée ; les noms sont ceux du fichier, en <code>snake_case</code>.",
            ], "kealsql --queries blog.kealsql > queries.sql\npsql -d blog\n\nblog=> \\i queries.sql\nblog=> INSERT INTO \"user\" (name, email) VALUES ('ada', 'ada@x'), ('bob', 'bob@x');\nblog=> INSERT INTO post (author, editor, title, status, created) VALUES\n         (1, 2, 'Hello', 'Published', now()),\n         (1, NULL, 'Draft one', 'Draft', now()),\n         (2, NULL, 'Bob post', 'Published', now());\nblog=> EXECUTE by_author('ada');\nblog=> EXECUTE editor_of(2);\nblog=> EXECUTE drafts;\nblog=> \\q", " id | title\n----+-------\n  1 | Hello\n(1 row)\n\n name\n------\n\n(1 row)\n\n count\n-------\n     1\n(1 row)", [
                "<code>editor_of(2)</code> répond une ligne qui ne tient rien : le billet 2 existe et n'a pas d'éditeur. C'est la jointure gauche que le <code>?.</code> du fichier demandait. <code>by_author('ada')</code> répond un billet, pas deux : le fichier dit <code>status == Published</code>, et le second billet d'Ada est un brouillon.",
            ]),
            ("Écrire un programme Keal qui s'en sert", [
                "Maintenant les mêmes requêtes depuis un programme. Un programme Keal importe le fichier <code>.kealsql</code> lui-même ; le chargeur de Keal lance <code>kealsql</code> pour écrire un module à côté, <code>.kealsql/blog.client.keal</code>, où chaque requête est une méthode sur une connexion. Écrivez <code>app.keal</code> à côté de <code>blog.kealsql</code> :",
            ], ("app.keal", "import \"./blog.kealsql\"\n\n// La base et ses tables, créées si elles manquent ; une connexion dessus.\nval db = createBlog(\"\", \"blog\")\n\nprintln(\"drafts: ${db.drafts()}\")\nfor (p in db.byAuthor(\"ada\")) {\n    println(\"#${p.id} ${p.title}\")\n}\nval editor = db.editorOf(1)\nprintln(\"editor of #1: ${editor ?: \"none\"}\")\ndb.close()"), None, [
                "<code>createBlog(\"\", \"blog\")</code> : le premier argument est une chaîne de connexion libpq — vide, elle prend les mêmes défauts que <code>psql</code> (votre utilisateur, le serveur local) ; le second est le nom de la base, créée si elle n'existe pas. Ici elle existe, avec des lignes, donc l'appel ne fait que se connecter.",
                "<code>db.byAuthor(\"ada\")</code> répond une liste de records avec <code>id</code> et <code>title</code> ; <code>db.editorOf(1)</code> répond un <code>String?</code>, d'où le <code>?: \"none\"</code>.",
            ]),
            ("Le construire et le lancer", [
                "Le programme se lie à <code>libpq</code>, la bibliothèque cliente de PostgreSQL ; les deux drapeaux disent où sont son en-tête et sa bibliothèque.",
            ], "keal build app.keal -I$(pg_config --includedir) -lpq -o app\n./app\nls .kealsql", "drafts: 1\n#1 Hello\neditor of #1: bob\nblog.client.keal", [
                "Le répertoire <code>.kealsql/</code> tient le module généré. Commitez-le avec le projet : un checkout se construit alors sans <code>kealsql</code> installé, et Keal le régénère dès que <code>blog.kealsql</code> est plus récent.",
                "<strong>Si ça ne marche pas :</strong> <em>cannot generate … `kealsql` is not installed</em> — le binaire de l'étape 6 n'est pas sur le chemin ; <code>export KEALSQL=/chemin/vers/kealsql</code>. <em>libpq-fe.h: No such file</em> — installez <code>libpq-dev</code> (Linux) et vérifiez <code>pg_config --includedir</code>. <em>connection refused</em> ou <em>authentication failed</em> — étape 5.",
            ]),
            ("Changer le fichier, et laisser le compilateur vous rattraper", [
                "Renommez la requête <code>drafts</code> en <code>draftCount</code> dans <code>blog.kealsql</code> et reconstruisez le programme, sans y toucher :",
            ], "sed -i 's/func drafts()/func draftCount()/' blog.kealsql\nkeal build app.keal -I$(pg_config --includedir) -lpq -o app", "error: `BlogDb` has no method `drafts`\n  --> app.keal:6:23", [
                "Le chargeur a vu que le fichier était plus récent, a régénéré le module, et le programme a cessé de compiler à la ligne qui utilisait l'ancien nom. C'est tout le propos : une requête que le fichier n'a plus est une erreur dans le programme, pas un échec à l'exécution. Remettez <code>drafts</code>, ou corrigez le programme.",
            ]),
            ("Faire évoluer le schéma", [
                "Ajoutez une colonne au fichier — <code>bio: String?</code> y est déjà ; ajoutez <code>joined: Date?</code> dessous dans <code>User</code> — et demandez ce qui manque à la base vivante :",
            ], "kealsql --migrate blog.kealsql --db blog", "ALTER TABLE \"user\" ADD COLUMN joined date;", [
                "Rien n'a été appliqué : la migration est imprimée pour que vous la lisiez. Appliquez-la en une transaction et redemandez — la réponse doit être <em>nothing to do</em> :",
            ]),
            ("Appliquer la migration", [], "kealsql --migrate blog.kealsql --db blog > migration.sql\npsql -1 -d blog -f migration.sql\nkealsql --migrate blog.kealsql --db blog", "-- nothing to do: the database matches the declaration", [
                "Une colonne supprimée, un type rétréci ou un nouveau <code>NOT NULL</code> seraient imprimés en commentaires, retenus jusqu'à ce que vous passiez <code>--destructive</code> — le compilateur nomme ce qu'ils coûteraient. Un renommage n'est jamais deviné : écrivez <code>renamed(ancienNom) nouveauNom: Type</code> dans le fichier, et la migration renomme.",
            ]),
            ("Du Keal dans le serveur (Linux et macOS)", [
                "Une <code>stored func</code> est du Keal que PostgreSQL exécute comme fonction native. Ajoutez-en une à <code>blog.kealsql</code> et servez-vous-en dans une requête :",
            ], ("blog.kealsql (ajouté)", "stored pure func shout(s: String): String { s.toUpper() + \"!\" }\n\nfunc shouted(): List<String> {\n    from(Post).orderBy(id).select(shout(title))\n}"), None, [
                "Puis générez la source de la bibliothèque, construisez-la contre les en-têtes serveur, et chargez les fonctions avec le chemin de la bibliothèque — <code>--queries</code>, parce que les tables existent :",
            ]),
            ("Construire et charger la bibliothèque", [], "kealsql --plkeal build/ blog.kealsql\nsh build/build.sh\nkealsql --lib \"$PWD/build/blog.so\" --queries blog.kealsql | psql -d blog\npsql -d blog -c \"SELECT shout('hello')\"", " shout\n--------\n HELLO!\n(1 row)", [
                "<strong>Si ça ne marche pas :</strong> <em>postgres.h: No such file</em> — les en-têtes serveur manquent : <code>postgresql-server-dev-all</code> sous Debian et Ubuntu. Sous Windows cette étape n'est pas encore disponible.",
            ]),
            ("Et ensuite", [
                "<a href=\"start.html\">Premiers pas</a> est le même parcours en cinq minutes ; <a href=\"docs.html\">les docs</a> tiennent le design, la grammaire avec ce que chaque construction compile, et le README. <a href=\"https://github.com/geneacta/kealsql/blob/main/examples/shop.kealsql\">examples/shop.kealsql</a> est un vrai fichier plus gros à lire ensuite.",
            ], None, None, []),
        ],
    },
}
