
begin;

ALTER table problem
    ADD column geocode BYTEA;

commit;
