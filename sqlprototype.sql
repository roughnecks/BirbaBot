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

-- EXAMPLE TABLE which will store the content of each feed item. (feed_handle)
-- f_id is the feed id number (incremental); f_handle is the same as in the rss table.

CREATE TABLE IF NOT EXISTS feed_laltromondo (
        f_id          	INTEGER PRIMARY KEY,
        f_handle    	TEXT,
        title	    	VARCHAR(255),
        author		VARCHAR(255),
	url	    	TEXT,
	data		TEXT,
	body		TEXT
);

CREATE TABLE IF NOT EXISTS feed_lamerbot (
        f_id          	INTEGER PRIMARY KEY,
        f_handle    	TEXT,
        title	    	VARCHAR(255),
        author		VARCHAR(255),
	url	    	TEXT,
	data		TEXT,
	body		TEXT
);


--- SECTION 2
--- Load some sample data
---

INSERT INTO rss VALUES (NULL, '2011-10-05 00:10:00', 'laltrowiki', '#l_altromondo', 'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss', 1);
INSERT INTO rss VALUES (NULL, '2011-10-05 00:11:00', 'lamerbot', '#l_altro_mondo', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss', 1);
INSERT INTO rss VALUES (NULL, '2011-10-05 00:11:00', 'lamerbot', '#lamerbot', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss', 0);

INSERT INTO feed_laltromondo VALUES (NULL, 'laltromondo', 'first commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;01', 'blahblahdata1', 'blahblahbody1');
INSERT INTO feed_laltromondo VALUES (NULL, 'laltromondo', 'second commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;02', 'blahblahdata2', 'blahblahbody2');
INSERT INTO feed_laltromondo VALUES (NULL, 'laltromondo', 'third commit', 'melmoth', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;03', 'blahblahdata3', 'blahblahbody3');

INSERT INTO feed_lamerbot VALUES (NULL, 'lamerbot', 'first commit', 'melmothx', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;f=info01', 'blahblahdata3', 'blahblahbody3');
INSERT INTO feed_lamerbot VALUES (NULL, 'lamerbot', 'second commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;f=info02', 'blahblahdata4', 'blahblahbody5');

--- SECTION 3: documented queries

-- query rss table to see which urls needs to be for which channel
SELECT url,f_channel FROM rss WHERE active=1;

-- query feed_handle table(s) to get already fetched urls
SELECT url FROM feed_laltromondo;

-- query a feed_name to get the last fetched item id for feed_handle
SELECT f_id FROM feed_laltromondo ORDER BY f_id DESC LIMIT 1;

-- query a feed_name to get the last 2 fetched items for feed_handle (from all tables)
SELECT * FROM feed_laltromondo ORDER BY f_id DESC LIMIT 2;

-- query a feed_name to get the last 2 fetched items for feed_handle (from selected tables)
SELECT f_handle,title,url FROM feed_laltromondo ORDER BY f_id DESC LIMIT 2;
