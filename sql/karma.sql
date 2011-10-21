CREATE TABLE IF NOT EXISTS karma (
       nick  	VARCHAR(30) UNIQUE,
       last	BIGINT,
       level	INTEGER
);

SELECT level FROM karma WHERE nick = ?;

UPDATE karma SET level = ? where nick = ?;


