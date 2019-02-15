BEGIN;

ALTER TABLE users ADD COLUMN area_ids integer ARRAY;
UPDATE users SET area_ids = ARRAY[area_id] WHERE area_id IS NOT NULL;
ALTER TABLE users DROP COLUMN area_id;

COMMIT;
