BEGIN;

ALTER TABLE response_templates
    ADD COLUMN state TEXT;

COMMIT;
