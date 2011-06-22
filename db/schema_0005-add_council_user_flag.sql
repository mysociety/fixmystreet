begin;

ALTER table users
    ADD COLUMN from_authority boolean NOT NULL DEFAULT false;

commit;
