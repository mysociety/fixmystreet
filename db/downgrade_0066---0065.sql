BEGIN;

ALTER TABLE users ADD COLUMN area_id integer;
UPDATE users SET area_id = area_ids[1];
ALTER TABLE users DROP COLUMN area_ids;

COMMIT;

