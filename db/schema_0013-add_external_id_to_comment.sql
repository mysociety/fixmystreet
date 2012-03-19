begin;

ALTER TABLE comment
    ADD COLUMN external_id TEXT;

commit;
