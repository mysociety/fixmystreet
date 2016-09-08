BEGIN;

CREATE TABLE contact_response_templates (
    id serial NOT NULL PRIMARY KEY,
    contact_id int REFERENCES contacts(id) NOT NULL,
    response_template_id int REFERENCES response_templates(id) NOT NULL
);

ALTER TABLE response_templates
  ADD COLUMN auto_response boolean NOT NULL DEFAULT 'f';

COMMIT;
