BEGIN;

ALTER TABLE response_priorities
    DROP COLUMN description;

COMMIT;
