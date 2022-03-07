BEGIN;

ALTER TABLE problem
    ADD COLUMN send_fail_body_ids INT ARRAY NOT NULL DEFAULT '{}';

COMMIT;
