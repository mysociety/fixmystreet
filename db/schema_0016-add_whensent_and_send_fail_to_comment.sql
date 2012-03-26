begin;

ALTER table comment
    ADD column send_fail_count integer not null default 0;
ALTER table comment
    ADD column send_fail_reason text;
ALTER table comment
    ADD column send_fail_timestamp timestamp;
ALTER table comment
    ADD column whensent timestamp;
commit;
