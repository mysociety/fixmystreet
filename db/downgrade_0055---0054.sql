BEGIN;

ALTER TABLE response_priorities DROP COLUMN is_default;

COMMIT;

