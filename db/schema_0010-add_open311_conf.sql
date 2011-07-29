begin;

CREATE TABLE open311conf (
    id           SERIAL PRIMARY KEY,
    area_id      INTEGER NOT NULL unique,
    endpoint     TEXT NOT NULL,
    jurisdiction TEXT,
    api_key      TEXT
);

commit;
