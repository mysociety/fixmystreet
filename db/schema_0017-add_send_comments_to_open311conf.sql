begin;

ALTER table open311conf
    ADD column send_comments BOOL NOT NULL DEFAULT 'f';

commit;
