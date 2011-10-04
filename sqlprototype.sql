-- SECTION 1
-- Create a very simple database to hold book and author information
--
PRAGMA foreign_keys = ON;
CREATE TABLE rss (
        id          INTEGER PRIMARY KEY,
        title       TEXT ,
        url         TEXT
);

CREATE TABLE rss_lamer (
        id          INTEGER PRIMARY KEY,
        rss_name    TEXT,
        title	    TEXT,
	link	    TEXT
);


--- SECTION 2
--- Load some sample data
---
INSERT INTO rss VALUES (1, 'library', 'http://pippo.org');
INSERT INTO rss VALUES (2, 'library2', 'http://pluto.org');

INSERT INTO rss_lamer VALUES (1, 'prova', 'ciccia', 'http://pippo.org/1');
INSERT INTO rss_lamer VALUES (2, 'prova prova', 'altra ciccia', 'http://pluto.org/2');

--- SECTION 3: documented queries
-- query to see which urls we need to fetch
SELECT url FROM rss;
