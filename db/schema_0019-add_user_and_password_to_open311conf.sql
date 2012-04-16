begin;

ALTER TABLE open311conf
    ADD COLUMN username TEXT;

ALTER TABLE open311conf
    ADD COLUMN password TEXT;

commit;
