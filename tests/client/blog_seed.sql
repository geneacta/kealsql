INSERT INTO "user" (name, email) VALUES ('ada', 'ada@x'), ('bob', 'bob@x');
INSERT INTO post (author, editor, title, status, created) VALUES
    (1, 2, 'Hello', 'Published', '2026-01-01'),
    (1, NULL, 'Draft one', 'Draft', '2026-01-02'),
    (2, NULL, 'Bob post', 'Published', '2026-01-03');
