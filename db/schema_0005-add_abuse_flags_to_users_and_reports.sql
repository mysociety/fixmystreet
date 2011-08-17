begin;

ALTER table problem
    ADD column flagged BOOL NOT NULL DEFAULT 'f';

ALTER table users
    ADD column flagged BOOL NOT NULL DEFAULT 'f';

commit;
