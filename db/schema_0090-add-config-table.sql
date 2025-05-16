BEGIN;

CREATE TABLE config (
    key text not null primary key,
    value jsonb
);

COMMIT;
