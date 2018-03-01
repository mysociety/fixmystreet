BEGIN;

ALTER TABLE body ADD blank_updates_permitted boolean default 'f' not null;

COMMIT;
