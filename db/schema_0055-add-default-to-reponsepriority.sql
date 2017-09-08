BEGIN;

ALTER TABLE response_priorities ADD is_default boolean not null default 'f';

COMMIT;
