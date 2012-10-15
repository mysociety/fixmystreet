begin;

ALTER table open311conf
    ADD column can_be_devolved BOOL NOT NULL DEFAULT 'f';

ALTER table contacts
    ADD column endpoint TEXT,
    ADD column jurisdiction TEXT DEFAULT '',
    ADD column api_key TEXT DEFAULT '',
    ADD column send_method TEXT
;

commit;
