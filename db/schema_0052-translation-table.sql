BEGIN;

CREATE TABLE translation (
    id serial not null primary key,
    tbl text not null,
    object_id integer not null,
    col text not null,
    lang text not null,
    msgstr text not null,
    unique(tbl, object_id, col, lang)
);

COMMIT;
