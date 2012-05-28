begin;

ALTER TABLE comment
    ADD COLUMN extra TEXT;

commit;
