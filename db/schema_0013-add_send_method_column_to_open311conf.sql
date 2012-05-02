
begin;

ALTER table open311conf
    ADD column send_method TEXT;

commit;
