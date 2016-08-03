BEGIN;
ALTER TABLE users
ADD COLUMN area_id integer;
COMMIT;
