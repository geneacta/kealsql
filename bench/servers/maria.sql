-- The blog on MariaDB: the same tables, rows and function as on PostgreSQL.
CREATE TABLE user (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL UNIQUE, email TEXT NULL);
CREATE TABLE post (id INT AUTO_INCREMENT PRIMARY KEY, author INT NOT NULL REFERENCES user(id) ON DELETE CASCADE,
                   title TEXT NOT NULL, status ENUM('Draft', 'Published') NOT NULL);
-- Ids given by hand: InnoDB may leave gaps in AUTO_INCREMENT after an INSERT ... SELECT,
-- and the posts below name their authors by id.
INSERT INTO user (id, name) SELECT seq, CONCAT('u', seq) FROM seq_1_to_19;
INSERT INTO user (id, name) VALUES (20, 'ada');
INSERT INTO post (author, title, status) SELECT 1 + (seq % 20), CONCAT('post ', seq), IF(seq % 2 = 0, 'Published', 'Draft') FROM seq_1_to_400;
DELIMITER //
CREATE FUNCTION steps_sql(n BIGINT) RETURNS BIGINT DETERMINISTIC
BEGIN
    DECLARE x BIGINT DEFAULT n; DECLARE k BIGINT DEFAULT 0;
    WHILE x <> 1 DO
        IF x % 2 = 0 THEN SET x = x DIV 2; ELSE SET x = 3 * x + 1; END IF;
        SET k = k + 1;
    END WHILE;
    RETURN k;
END //
DELIMITER ;
