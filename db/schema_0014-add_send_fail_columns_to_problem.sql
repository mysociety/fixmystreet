begin;

ALTER table problem
    ADD column send_fail_count integer not null default 0;
ALTER table problem
    ADD column send_fail_reason text; 
ALTER table problem
    ADD column send_fail_timestamp timestamp;

commit;
