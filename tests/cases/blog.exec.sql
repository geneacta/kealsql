-- Run after blog.sql in the same session; the output is blog.exec.out.
INSERT INTO "user" (name, email) VALUES ('ada', 'ada@x'), ('bob', 'bob@x');
INSERT INTO post (author, editor, title, status, created) VALUES
    (1, 2, 'Hello', 'Published', '2026-01-01'),
    (1, NULL, 'Draft one', 'Draft', '2026-01-02'),
    (2, NULL, 'Bob post', 'Published', '2026-01-03');
EXECUTE by_author('ada');
EXECUTE editor_of(1);        -- bob
EXECUTE editor_of(2);        -- one row, null: the left join keeps the post
EXECUTE drafts;              -- 1
EXECUTE publish(2);
EXECUTE drafts;              -- 0
EXECUTE forget(2);           -- bob's post goes; ada's stay
SELECT count(*) FROM post;
