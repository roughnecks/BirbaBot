PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS factoids (
        id                      INTEGER PRIMARY KEY,
        key	                VARCHAR(30) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS definitions (
	foo			VARCHAR(30) NOT NULL,
	bar1			TEXT NOT NULL,
	bar2			TEXT,
	bar4			TEXT,
	bar5			TEXT,
	FOREIGN KEY(foo) REFERENCES factoids(key) ON DELETE CASCADE
);
