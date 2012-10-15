BEGIN;

    ALTER TABLE problem
        ALTER COLUMN interest_count SET DEFAULT 0;

    UPDATE problem SET interest_count = 0
        WHERE interest_count IS NULL;

COMMIT;
