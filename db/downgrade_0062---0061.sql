BEGIN;

ALTER TABLE users DROP created;
ALTER TABLE users DROP last_active;

COMMIT;
