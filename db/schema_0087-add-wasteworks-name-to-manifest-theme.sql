BEGIN;

ALTER TABLE manifest_theme ADD wasteworks_name text;
ALTER TABLE manifest_theme ADD wasteworks_short_name text;

COMMIT;
