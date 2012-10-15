begin;

ALTER table problem
    ADD column external_source TEXT;
ALTER table problem
    ADD column external_source_id TEXT;

commit;
