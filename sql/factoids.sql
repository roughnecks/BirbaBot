
CREATE TABLE IF NOT EXISTS factoids (
        id                      INTEGER PRIMARY KEY,
	nick			VARCHAR(30),
        key	                VARCHAR(30) UNIQUE NOT NULL,
	bar1			TEXT NOT NULL,
	bar2			TEXT,
	bar3			TEXT
);

SELECT '
aggiungere un fattoide, primo valore, non nullo
';

INSERT INTO factoids (id, nick, key, bar1) VALUES (NULL, 'ruff', 'test', 'just a test');

SELECT '
AGGIUNGERE BAR2/3 AL PRIMO FATTOIDE (key is also)
';

UPDATE factoids SET bar2 = CASE WHEN bar2 IS NULL THEN 'bar2' WHEN bar2 IS NOT NULL THEN (SELECT bar2 FROM factoids where key = 'test') END, bar3 = CASE WHEN bar2 IS NOT NULL THEN 'bar3' WHEN bar2 IS NULL THEN (SELECT bar3 FROM factoids where key = 'test') END WHERE key='test';

SELECT '
il punto è che adesso, se copi la query UPDATE sopra e la reincolli nell editor sql, vedi che ti aggiunge anche bar3, senza toccare bar2
oppure semplicemente reimporta il sql, ti darà errore sull insert, che è giusto e poi aggiunge bar3
';

SELECT '
adesso proviamo a cancellare bar2: uso sempre update, perché delete cancella la riga, non la colonna
diciamo che la prima definizione è bar1, come comando avremo "kw blah forget 2"
';

UPDATE factoids SET bar2=NULL WHERE key='test';

SELECT '
per cancellare bar3 mi pare scontato, si cambia bar2 nella query sopra con bar3 e il comando sarà tipo "kw blah froget 3"
mentre per cancellare tutto faremo "kw blah forget", senza parametri e la query la butto sotto
';

DELETE FROM factoids WHERE key='test';

