begin;

ALTER TABLE problem
    ADD COLUMN extra TEXT;

commit;
