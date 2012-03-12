CREATE TABLE IF NOT EXISTS karma (
       nick  	VARCHAR(30) UNIQUE,
       last	BIGINT,
       level	INTEGER
);

INSERT INTO karma (nick, last, level) VALUES ( ?, ?, ?);

SELECT level,last FROM karma WHERE nick = ?;

UPDATE karma,last SET level = ?,last = ? where nick = ?;


