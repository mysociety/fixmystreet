begin;

ALTER table users
    ADD COLUMN from_council integer;

commit;
