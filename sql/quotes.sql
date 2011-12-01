CREATE TABLE IF NOT EXISTS quotes (
        id      INTEGER PRIMARY KEY,
        chan    VARCHAR(30),
        author  VARCHAR(30),
	phrase	TEXT
);

SELECT '
Aggiungo 3 quotes
';

INSERT INTO quotes (id, chan, author, phrase) VALUES (NULL, '##laltromondo', 'rough', 'che belle le quotes!!');

INSERT INTO quotes (id, chan, author, phrase) VALUES (NULL, '##laltromondo', 'rough', 'oh, ma sono belle le quotes!!');

INSERT INTO quotes (id, chan, author, phrase) VALUES (NULL, '##laltromondo', 'rough', 'ma davvero, non sono una figata le quotes?');

SELECT * FROM quotes;

SELECT '
Elimino  la quote 2
';

DELETE FROM quotes WHERE id=2;
SELECT * FROM quotes;


SELECT '
Aggiungo una quarta dopo il buco
';

INSERT INTO quotes (id, chan, author, phrase) VALUES (NULL, '##laltromondo', 'rough', 'oh, chi ha cancellato la mia quote?');
SELECT * FROM quotes;

SELECT '
Richiedo una quote specifica: la 4
';

SELECT author,phrase FROM quotes WHERE id='4';

SELECT '
Cerco una stringa tra tutte le quotes ("cancellato")
';

SELECT author,phrase FROM quotes WHERE phrase LIKE '%cancellato%';


SELECT '
Cerco l ultima quote
';

SELECT author,phrase FROM quotes ORDER BY id DESC LIMIT 1;

SELECT '
Cerco una quote random
';

SELECT author,phrase FROM quotes WHERE id='random_num';
