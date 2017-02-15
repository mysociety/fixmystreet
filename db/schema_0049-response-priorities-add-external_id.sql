BEGIN;

ALTER TABLE response_priorities
    ADD COLUMN external_id TEXT;

COMMIT;
