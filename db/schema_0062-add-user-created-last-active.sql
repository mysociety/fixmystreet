BEGIN;

ALTER TABLE users ADD created timestamp default current_timestamp not null;
ALTER TABLE users ADD last_active timestamp default current_timestamp not null;

COMMIT;

