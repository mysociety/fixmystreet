BEGIN;

ALTER TABLE body ADD fetch_problems boolean default 'f' not null;

COMMIT;
