BEGIN;

ALTER table body
    ADD column deleted BOOL NOT NULL DEFAULT 'f';

COMMIT;
