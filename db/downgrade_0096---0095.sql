BEGIN;

ALTER TABLE response_templates DROP COLUMN old_external_status_code;

COMMIT;
