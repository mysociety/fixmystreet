BEGIN;

ALTER TABLE problem DROP COLUMN response_priority_id;
DROP TABLE contact_response_priorities;
DROP TABLE response_priorities;

COMMIT;
