BEGIN;

ALTER TABLE response_templates ADD external_status_code text;

COMMIT;
