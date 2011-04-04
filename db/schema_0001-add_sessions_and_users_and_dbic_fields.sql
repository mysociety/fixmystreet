-- These are changes needed to the schema to support moving over to DBIx::Class

begin;

-- table for sessions - needed by Catalyst::Plugin::Session::Store::DBIC
CREATE TABLE sessions (
    id           CHAR(72) PRIMARY KEY,
    session_data TEXT,
    expires      INTEGER
);

-- users table
create table users (
    id              serial  not null primary key,
    email           text    not null unique,
    name            text,
    phone           text,
    password        text    not null default ''
);

-- rollback;
commit;
