CREATE TABLE IF NOT EXISTS notes (
       date  	    DATETIME,
       sender	    VARCHAR(30),
       receiver	    VARCHAR(30) NOT NULL,
       message	    TEXT NOT NULL
);

SELECT sender,message,date FROM notes WHERE receiver='';

DELETE FROM notes WHERE receiver='';

