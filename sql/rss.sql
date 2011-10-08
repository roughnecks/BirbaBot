PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS rss (
        f_handle        VARCHAR(30) PRIMARY KEY NOT NULL,
        url             TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS channels (
        f_handle        VARCHAR(30) NOT NULL,
        f_channel       VARCHAR(30) NOT NULL,
        FOREIGN KEY(f_handle) REFERENCES rss(f_handle) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS feeds (
        id                      INTEGER PRIMARY KEY,
        date                    DATETIME,
        f_handle                VARCHAR(30) NOT NULL,
        title                   VARCHAR(255),
        author                  VARCHAR(255),
        url                     TEXT UNIQUE NOT NULL,
        FOREIGN KEY(f_handle) REFERENCES rss(f_handle)
);
