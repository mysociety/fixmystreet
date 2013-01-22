begin;

ALTER table open311conf
    ADD column send_extended_statuses BOOL NOT NULL DEFAULT 'f';

commit;
