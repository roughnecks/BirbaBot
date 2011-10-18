CREATE TABLE IF NOT EXISTS notes (
       date  	    VARCHAR(150),
       sender	    VARCHAR(30),
       recipient    VARCHAR(30) NOT NULL,
       message	    TEXT NOT NULL
);

SELECT sender,message,date FROM notes WHERE recipient='';

DELETE FROM notes WHERE recipient='';

INSERT INTO notes (date, sender, recipient, message) VALUES ( ,'' ,'' ,'');
