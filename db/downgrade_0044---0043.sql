BEGIN;

ALTER TABLE response_templates DROP COLUMN auto_response;

DROP TABLE contact_response_templates;

COMMIT;
