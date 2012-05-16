begin;

ALTER table problem
    ADD column send_method_used text; 

commit;
