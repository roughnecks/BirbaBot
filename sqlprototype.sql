-- SECTION 1
-- Create a very simple database to hold rss feeds list and content informations.
--

-- TABLE which will store the feeds' items list. (rss)
--

PRAGMA foreign_keys = ON;
CREATE TABLE rss (
        r_id    	INTEGER PRIMARY KEY,
	date		DATETIME,
	f_handle	varchar(255),
        url     	TEXT
);

-- EXAMPLE TABLE which will store the content of each feed item. (feed_name)
--

CREATE TABLE feed_laltromondo (
        f_id          	INTEGER PRIMARY KEY,
	date		DATETIME,
        f_handle    	TEXT,
        title	    	VARCHAR(255),
        author		VARCHAR(255),
	url	    	TEXT,
	data		TEXT,
	body		TEXT
);

CREATE TABLE feed_lamerbot (
        f_id          	INTEGER PRIMARY KEY,
	date		DATETIME,
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

INSERT INTO rss VALUES (NULL, '2011-10-05 00:10:00', 'laltrowiki', 'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss');
INSERT INTO rss VALUES (NULL, '2011-10-05 00:11:00', 'lamerbot', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss');

INSERT INTO feed_laltromondo VALUES (NULL, '2011-10-05 00:12:00', 'laltromondo', 'first commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;f', 'blahblahdata1', 'blahblahbody1');
INSERT INTO feed_laltromondo VALUES (NULL, '2011-10-05 00:13:00', 'laltromondo', 'second commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;', 'blahblahdata2', 'blahblahbody2');

INSERT INTO feed_lamerbot VALUES (NULL, '2011-10-05 00:15:00', 'lamerbot', 'first commit', 'melmothx', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;f=in', 'blahblahdata3', 'blahblahbody3');
INSERT INTO feed_lamerbot VALUES (NULL, '2011-10-05 00:16:00', 'lamerbot', 'second commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;f=info', 'blahblahdata4', 'blahblahbody5');

--- SECTION 3: documented queries

-- query to see which urls we need to fetch
SELECT url FROM rss;

-- query a feed_name to get the last fetched item id
SELECT f_id FROM feed_laltromondo ORDER BY f_id DESC LIMIT 1;

-- query a feed_name to get the last 2 fetched items (from all tables)
SELECT * FROM feed_laltromondo ORDER BY f_id LIMIT 2;

-- query a feed_name to get the last 2 fetched items (from selected tables)
SELECT f_handle,title,url FROM feed_laltromondo ORDER BY f_id LIMIT 2;
