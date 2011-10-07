-- SECTION 1
-- Create a very simple database to hold rss feeds list and content informations.
--

-- TABLE which will store the feeds' items list. (rss)
-- r_id is the rss id number (incremental); f_handle is the friendly name of the feed; "active" tells if the the feed is currently watched on f_channel. 
-- If the same feed is used in multiple channels, we use two different records with all the same columns and different channel/active values.

SELECT '
Una foreign key è una costrizione che lega due tabelle in modo da non immettere dati sbagliati né perderli. esempio:
2 tabelle, artisti e canzoni: negli artisti si fa la lista (come rss), nelle canzoni si associa la canzone all artista (come feeds)
Ora andando al nostro caso: se cerchi di aggiungere una canzone con un artista che non è in lista nell altra tabella, ti dà errore.
Se cerchi di eliminare un artista che ha delle canzoni nell altra tabelle, ti dà errore.
Quindi, riassumendo, non si possono eliminare voci dal menu rss finché esistono feeds connessi e non si possono aggiungere feeds se non vi è una voce reletiva sul menu rss
Se è tutto ok e le vogliamo usare per gli rss, provo a farle funzionare
';

SELECT '
abilito le foreign keys
';

PRAGMA foreign_keys = ON;

SELECT '
Come PRIMARY KEY imposto feedname ("testo" e non INTEGER) e tolgo r_id che è superfluo
In seguito a un problema con le foreign keys, ho modificato la struttura ed aggiunto una tabella, (vedi sotto).
in rss abbiamo solo nome del feed, tipo slashdot e suo url.
';

CREATE TABLE IF NOT EXISTS rss (
        f_handle   	VARCHAR(30) PRIMARY KEY NOT NULL,
        url     	TEXT UNIQUE
);


--- SECTION 2
--- Load some sample data
---

INSERT INTO rss VALUES ('laltrowiki', 'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss');
INSERT INTO rss VALUES ('lamerbot', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss');

--- SECTION 3: documented queries

SELECT '
questa tabella mantiene solo la lista dei feed che si possono eventualmente abilitare nei vari canali (i feed disponibili)
l unica query che torna utile è quela che ci dice appunto quali quali feed possiamo abilitare
';

SELECT f_handle FROM rss;


SELECT '
aggiungo ora una tabella per sapere quale feed è disponibile su quale canale e se è attivo o meno
anche qui uso una foreign key alla tabella principale (rss) e vale lo stesso discorso di sopra
non posso aggiungere il feed slashdot sul canale f_channel se il feed stesso non è già presente nella lista rss, mentre posso cancellarlo: vedi esempio
al contrario non posso eliminare il feed slashdot dalla lista degli rss se ho dei canali col feed "inserito", sia che sia active o meno
';


CREATE TABLE IF NOT EXISTS channels (
        f_handle        VARCHAR(30) NOT NULL,
	f_channel	VARCHAR(30) NOT NULL,
        active		BOOLEAN,
	FOREIGN KEY(f_handle) REFERENCES rss(f_handle) ON DELETE CASCADE
);


INSERT INTO channels VALUES ('laltrowiki', '#l_altro_mondo', 1);
INSERT INTO channels VALUES ('lamerbot', '#l_altro_mondo', 0);
INSERT INTO channels VALUES ('lamerbot', '#lamerbot', 1);

SELECT '
errore voluto, rss non presente in menu
';

INSERT INTO channels VALUES ('rbot', '#l_altro_mondo', 1);


SELECT '
query channels for active feeds
';

SELECT f_handle FROM channels WHERE active=1;




-- EXAMPLE TABLES which will store the content of each feed item. (feed_handle)
-- f_id is the feed id number (incremental); f_handle is the same as in the rss table.

SELECT '
Nella tabella feeds l id rimane come PRIMARY KEY e f_handle diviene la nostra FOREIGN KEY, associata al feedname della tabella rss.
Cancellando uno o più elementi in feeds non succede nulla, mentre cancellare un elemento dall elenco in rss, qualora ci siano ancora feeds, ritorna errore.
Allo stesso tempo non si può inserire un elemento nella tabella feed se non vi è una voce feedname corrispondente nella tabella rss.
';

CREATE TABLE IF NOT EXISTS feeds (
        id          		INTEGER PRIMARY KEY,
	date			DATETIME,
	f_handle		VARCHAR(30) NOT NULL,
        title	    		VARCHAR(255),
        author			VARCHAR(255),
	url	    		TEXT UNIQUE,
	description		TEXT,
	FOREIGN KEY(f_handle) REFERENCES rss(f_handle)
);

--- SECTION 2
--- Load some sample data
---

INSERT INTO feeds VALUES (NULL, DATETIME('NOW'), 'laltrowiki', 'first commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;01', 'blahblahdata1');
SELECT '
here there is a wanted error caused by the url in the next INSERT statement wich is not unique
';

INSERT INTO feeds VALUES (NULL, DATETIME('NOW'), 'laltrowiki', 'second commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;01', 'blahblahdata2');
INSERT INTO feeds VALUES (NULL, '2011-10-04 20:17:00', 'laltrowiki', 'second commit', 'melmoth', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;02', 'blahblahdata2');
INSERT INTO feeds VALUES (NULL, '2011-10-06 20:17:00', 'laltrowiki', 'third commit', 'melmoth', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;03', 'blahblahdata3');
INSERT INTO feeds VALUES (NULL, '2011-10-07 21:18:00', 'laltrowiki', 'fourth commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;04', 'blahblahdata4');


--- SECTION 3: documented queries for feeds TABLES

SELECT '
query feed_handle table(s) to get already fetched urls from a particular feed (laltrowiki)
';
SELECT url FROM feeds WHERE f_handle='laltrowiki';

SELECT '
query a feed_name to get the last fetched item id for feed_handle laltrowiki
';
SELECT id FROM feeds WHERE f_handle='laltrowiki' ORDER BY id DESC LIMIT 1;


--- SECTION 4: test some DELETE

SELECT '
this query shows the actual situation of already fetched feeds for laltrowiki with their ids
';

SELECT id,title FROM feeds WHERE f_handle='laltrowiki';

SELECT '
now we delete one row in the middle and look how it goes with ids
';

DELETE FROM feeds WHERE title='third commit';

SELECT id,title FROM feeds WHERE f_handle='laltrowiki';

SELECT '
finally we add a new feed to see further
';

INSERT INTO feeds VALUES (NULL, '2011-10-08 21:18:00', 'laltrowiki', 'fifth commit', 'rough', 'http://laltromondo.dynalias.net/gitweb?p=LAltroWiki.git;a=blobdiff;05', 'blahblahdata5');

SELECT id,title FROM feeds WHERE f_handle='laltrowiki';


SELECT '
provo a cancellare un rss quando ci sono notizie nella tabella feeds per testare le FOREYGN KEYS
';

DELETE FROM rss WHERE f_handle='laltrowiki';

SELECT '
adesso cancello tutti le notizie relative a laltrowiki e poi riprovo a cancellare la entry in rss e relative entry nella tabella canali
';

DELETE FROM feeds WHERE f_handle='laltrowiki';
DELETE FROM rss WHERE f_handle='laltrowiki';


--- SECTION 5: test if we are able to DELETE an rss item and all related feeds and channels

-- SELECT '
-- per eliminare un rss del tutto, prima si cancellano le notizie che riguardano il feed stesso
-- ';

-- DELETE FROM feeds WHERE f_handle='laltrowiki';

-- SELECT '
-- poi si cancela la entry nel menu rss ed automagicamente se ne vanno tutti i record per quel feed dalla tabella channels
-- ';

-- DELETE FROM rss WHERE f_handle IN (SELECT f_handle FROM channels WHERE f_handle = 'laltrowiki');

-- SELECT '
-- dovrei riuscire a cancellare tutto con un solo delete: work in progress
-- ';

