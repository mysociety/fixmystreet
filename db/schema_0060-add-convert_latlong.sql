BEGIN;

ALTER TABLE body ADD convert_latlong boolean default 'f' not null;

COMMIT;
