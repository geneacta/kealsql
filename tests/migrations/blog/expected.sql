ALTER TYPE status ADD VALUE 'Archived';
ALTER TABLE post RENAME TO article;
CREATE TABLE comment (
    id serial PRIMARY KEY,
    article integer NOT NULL REFERENCES article(id) ON DELETE CASCADE,
    body text NOT NULL
);
ALTER TABLE "user" RENAME COLUMN bio TO about;
ALTER TABLE "user" ALTER COLUMN nick TYPE varchar(20);
ALTER TABLE "user" ADD COLUMN joined date;
-- DESTRUCTIVE, held back (pass --destructive to emit it): a NOT NULL column without a default fails if `user` has rows; add it optional and backfill, or give it a default
-- ALTER TABLE "user" ADD COLUMN karma integer NOT NULL;
ALTER TABLE article ALTER COLUMN created DROP NOT NULL;
ALTER TABLE article ADD COLUMN tags text;
ALTER TABLE article DROP CONSTRAINT post_author_fkey;
ALTER TABLE article ADD CONSTRAINT article_author_fkey FOREIGN KEY (author) REFERENCES "user"(id) ON DELETE RESTRICT ON UPDATE NO ACTION;
-- DESTRUCTIVE, held back (pass --destructive to emit it): every row of `legacy` is lost
-- DROP TABLE legacy;
-- 2 statements held back
