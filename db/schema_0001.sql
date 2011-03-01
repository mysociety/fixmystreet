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
    id          serial not null primary key,
    email       text not null unique,
    name        text,
    password    text not null
);

-- add PK to contacts table
ALTER TABLE contacts
    ADD COLUMN id SERIAL PRIMARY KEY;

AlTER TABLE contacts_history
    ADD COLUMN contact_id integer;

update contacts_history
    set contact_id = (
        select id
        from contacts
        where contacts_history.category = contacts.category
          and contacts_history.area_id = contacts.area_id
    );

-- rollback;
commit;
