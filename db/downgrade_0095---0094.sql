BEGIN;

ALTER TABLE response_templates DROP COLUMN deleted;

COMMIT;
