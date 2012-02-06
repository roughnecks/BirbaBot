CREATE TABLE IF NOT EXISTS todo (
	id	INTEGER,
	chan	VARCHAR(30),
	todo	TEXT
);

--INSERT INTO todo VALUES ('1', '#l_altro_mondo', 'first todo');

--SELECT last_insert_rowid() FROM todo WHERE chan='#l_altro_mondo';

--INSERT INTO todo VALUES ('1', '#l_altro_mondo', 'first todo');
SELECT '
prima di ogni insert vediamo qual è l ultimo id per #canale col select max(id): alla prima query non restituisce nulla, credo sia proprio un null.
quindi per fare l insert bisogna aggiungere 1 (+1) al valore restituito dal select, che dovrebbe essere memorizzato in una variabile
';

SELECT MAX(id) FROM todo WHERE chan='#l_altro_mondo';

SELECT '
canale vuoto di todo, maxid per #l_altro_mondo nullo
a questo punto il perl memorizza il valore restitutito, che sarà 0
e si prosegue con l insert
';

--INSERT INTO todo VALUES ('1', '#l_altro_mondo', 'first todo');



--SELECT MAX(id) FROM todo WHERE chan='#l_altro_mondo';

INSERT INTO todo VALUES ('var_maxid +1', '#l_altro_mondo', 'second todo');

SELECT * FROM todo;

SELECT '
ogni nuovo insert funziona come sopra, si fa il select >> maxid in variable, poi l insert con $var+1
';

SELECT '
i delete sono semplici: si cancella per id su #canale
';

DELETE FROM todo WHERE chan='#l_altro_mondo' AND id='numero';

SELECT '
a questo punto abbiamo ogni canale con la sua numerazione che parte sempre da 1
il problema è quando coi delete "spezziamo" l ordinamento: 1 3 4 5 8
finché si lascia spezzato il delete funziona normalmente, è solo brutto a vedersi
quindi, a richiesta bisogna poter riordinare il tutto
qui entri in gioco tu, perché non so dove mettere le mali col sql
';

