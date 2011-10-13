
CREATE TABLE IF NOT EXISTS factoids (
        id                      INTEGER PRIMARY KEY,
	nick			VARCHAR(30),
        key	                VARCHAR(30) UNIQUE NOT NULL,
	bar1			TEXT NOT NULL,
	bar2			TEXT,
	bar3			TEXT
);

SELECT '
aggiungiamo un fattoide, primo valore, non nullo
';

INSERT INTO factoids (nick, key, bar1) VALUES ('ruff', 'test', 'just a test');

SELECT * FROM factoids;

SELECT '
aggiungiamo bar2 al primo fattoide (key is also)
';

UPDATE factoids SET bar2 = CASE WHEN bar2 IS NULL THEN 'bar2' WHEN bar2 IS NOT NULL THEN (SELECT bar2 FROM factoids where key = 'test') END, bar3 = CASE WHEN bar2 IS NOT NULL AND bar3 IS NULL THEN 'bar3' WHEN bar2 IS NULL THEN (SELECT bar3 FROM factoids where key = 'test') WHEN bar3 IS NOT NULL THEN (SELECT bar3 FROM factoids where key = 'test') END WHERE key='test';

SELECT * FROM factoids;

SELECT '
adesso, ripetendo la query, vedi che ti aggiunge anche bar3, senza toccare bar2
';

UPDATE factoids SET bar2 = CASE WHEN bar2 IS NULL THEN 'bar2' WHEN bar2 IS NOT NULL THEN (SELECT bar2 FROM factoids where key = 'test') END, bar3 = CASE WHEN bar2 IS NOT NULL AND bar3 IS NULL THEN 'bar3' WHEN bar2 IS NULL THEN (SELECT bar3 FROM factoids where key = 'test') WHEN bar3 IS NOT NULL THEN (SELECT bar3 FROM factoids where key = 'test') END WHERE key='test';

SELECT * FROM factoids;

SELECT '
e ripetendo ancora, lascia bar2 e bar3 ai volori già impostati perché non nulli: in questo caso, nello specifico dovrei fare in modo che ritornasse un errore, per far capire che i 3 bar sono già tutti impostati e non se ne può mettere un altro finché non si cancellano il 2 o il 3; solo non saprei come fare, magari puoi tu
';

UPDATE factoids SET bar2 = CASE WHEN bar2 IS NULL THEN 'bar2' WHEN bar2 IS NOT NULL THEN (SELECT bar2 FROM factoids where key = 'test') END, bar3 = CASE WHEN bar2 IS NOT NULL AND bar3 IS NULL THEN 'bar3' WHEN bar2 IS NULL THEN (SELECT bar3 FROM factoids where key = 'test') WHEN bar3 IS NOT NULL THEN (SELECT bar3 FROM factoids where key = 'test') END WHERE key='test';

SELECT * FROM factoids;

SELECT '
adesso proviamo a cancellare bar2: uso sempre update, perché delete cancella la riga, non la colonna
diciamo che la prima definizione è bar1, come comando avremo "kw blah forget 2"
';

UPDATE factoids SET bar2=NULL WHERE key='test';

SELECT * FROM factoids;

SELECT '
per cancellare bar3 mi pare scontato, si cambia bar2 nella query sopra con bar3 e il comando sarà tipo "kw blah froget 3"
';

UPDATE factoids SET bar3=NULL WHERE key='test';
SELECT * FROM factoids;

SELECT '
mentre per cancellare tutto faremo "kw blah forget", senza parametri e la query la butto sotto
';

DELETE FROM factoids WHERE key='test';

SELECT * FROM factoids;
