begin;

ALTER table open311conf
    ADD column suppress_alerts BOOL NOT NULL DEFAULT 'f';

commit;
