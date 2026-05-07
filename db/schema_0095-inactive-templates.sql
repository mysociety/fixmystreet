BEGIN;

ALTER TABLE response_templates
  ADD COLUMN deleted boolean NOT NULL DEFAULT 'f';

COMMIT;
