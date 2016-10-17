BEGIN;

ALTER TABLE response_priorities
    ADD COLUMN description TEXT;

COMMIT;
