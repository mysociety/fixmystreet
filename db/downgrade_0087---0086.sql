BEGIN;

ALTER TABLE manifest_theme DROP COLUMN wasteworks_name;
ALTER TABLE manifest_theme DROP COLUMN wasteworks_short_name;

COMMIT;
