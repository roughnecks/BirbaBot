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
	url	    	TEXT UNIQUE,
	data		TEXT
);

CREATE TABLE IF NOT EXISTS feed_lamerbot (
        f_id          	INTEGER PRIMARY KEY,
        f_handle    	TEXT,
        title	    	VARCHAR(255),
        author		VARCHAR(255),
	url	    	TEXT UNIQUE,
	data		TEXT
);


--- SECTION 2
--- Load some sample data
---

INSERT INTO rss VALUES (NULL, DATETIME('NOW'), 'laltrowiki', '#l_altro_mondo', 'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss', 1);
INSERT INTO rss VALUES (NULL, '2011-10-05 00:11:00', 'lamerbot', '#l_altro_mondo', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss', 1);
INSERT INTO rss VALUES (NULL, '2011-10-05 00:11:00', 'lamerbot', '#lamerbot', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss', 0);

INSERT INTO feed_laltromondo VALUES (NULL, 'laltromondo', 'first commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;01', 'blahblahdata1');
INSERT INTO feed_laltromondo VALUES (NULL, 'laltromondo', 'second commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;01', 'blahblahdata2');
INSERT INTO feed_laltromondo VALUES (NULL, 'laltromondo', 'third commit', 'melmoth', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;03', 'blahblahdata3');

INSERT INTO feed_lamerbot VALUES (NULL, 'lamerbot', 'first commit', 'melmothx', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;f=info01', 'blahblahdata3');
INSERT INTO feed_lamerbot VALUES (NULL, 'lamerbot', 'second commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;f=info02', 'blahblahdata4');
