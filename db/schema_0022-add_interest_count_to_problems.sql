begin;

ALTER table problem
    ADD COLUMN interest_count integer DEFAULT 0;

commit;
