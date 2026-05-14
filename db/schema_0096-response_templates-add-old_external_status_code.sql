BEGIN;

ALTER TABLE response_templates ADD old_external_status_code text NOT NULL DEFAULT '';

COMMIT;
