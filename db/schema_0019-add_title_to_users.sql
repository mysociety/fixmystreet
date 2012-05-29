-- These are changes needed to the schema to support moving over to DBIx::Class

begin;

AlTER TABLE users
    ADD COLUMN title text;

commit;
