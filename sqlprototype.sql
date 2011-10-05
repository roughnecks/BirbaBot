-- SECTION 1
-- Create a very simple database to hold rss feeds list and content informations.
--

-- TABLE which will store the feeds' items list. (rss)
-- r_id is the rss id number (incremental); f_handle is the friendly name of the feed; "active" tells if the the feed is currently watched on f_channel. 
-- If the same feed is used in multiple channels, we use two different records with all the same columns and different channel/active values.

PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS rss (
        r_id    	INTEGER PRIMARY KEY,
	date		DATETIME,
	f_handle	VARCHAR(255),
	f_channel	VARCHAR(30),
        url     	TEXT,
        active		BOOLEAN
);


--- SECTION 2
--- Load some sample data
---

INSERT INTO rss VALUES (NULL, DATETIME('NOW'), 'laltrowiki', '#l_altro_mondo', 'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss', 1);
INSERT INTO rss VALUES (NULL, '2011-10-05 00:11:00', 'lamerbot', '#l_altro_mondo', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss', 1);
INSERT INTO rss VALUES (NULL, '2011-10-05 00:11:00', 'lamerbot', '#lamerbot', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss', 0);

--- SECTION 3: documented queries

SELECT '
query rss table to see which urls needs to be fetched for which channel
';
SELECT url,f_channel FROM rss WHERE active=1;

SELECT '
query rss table to see which urls of which feed_handle needs to be fetched without duplicates
';
SELECT DISTINCT url,f_handle FROM rss WHERE active=1;

SELECT '
query rss table to select active feeds in channel f_channel (e.g. #laltromondo)
';
SELECT f_handle FROM rss WHERE f_channel='#l_altro_mondo' AND active=1;


-- EXAMPLE TABLES which will store the content of each feed item. (feed_handle)
-- f_id is the feed id number (incremental); f_handle is the same as in the rss table.

CREATE TABLE IF NOT EXISTS feed_laltromondo (
        id          	INTEGER PRIMARY KEY,
        title	    	VARCHAR(255),
        author		VARCHAR(255),
	url	    	TEXT UNIQUE,
	description	TEXT
);

--- SECTION 2
--- Load some sample data
---

INSERT INTO feed_laltromondo VALUES (NULL, 'first commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;01', 'blahblahdata1');
SELECT '
here there is a wanted error caused by the url in the next INSERT statement wich is not unique
';
INSERT INTO feed_laltromondo VALUES (NULL, 'second commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;01', 'blahblahdata2');
INSERT INTO feed_laltromondo VALUES (NULL, 'third commit', 'melmoth', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;03', 'blahblahdata3');


--- SECTION 3: documented queries for feeds TABLES

SELECT '
query feed_handle table(s) to get already fetched urls
';
SELECT url FROM feed_laltromondo;

SELECT '
query a feed_name to get the last fetched item id for feed_handle
';
SELECT id FROM feed_laltromondo ORDER BY id DESC LIMIT 1;

SELECT '
query a feed_name to get the last 2 fetched items for feed_handle (from all tables)
';
SELECT * FROM feed_laltromondo ORDER BY id DESC LIMIT 2;

