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

INSERT INTO todo VALUES ('1', '#l_altro_mondo', 'first todo');

SELECT MAX(id) FROM todo WHERE chan='#l_altro_mondo';

INSERT INTO todo VALUES ('var_maxid +1', '#l_altro_mondo', 'second todo');

SELECT * FROM todo;
