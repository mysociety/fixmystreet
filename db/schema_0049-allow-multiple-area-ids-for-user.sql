BEGIN;

ALTER TABLE users
    ADD COLUMN areas TEXT;

UPDATE users set areas = area_id;

ALTER TABLE users
    DROP COLUMN area_id;
    
COMMIT;
