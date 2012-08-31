BEGIN;

    ALTER TABLE contacts
        ADD COLUMN non_public BOOLEAN DEFAULT 'f';

    ALTER TABLE problem
        ADD COLUMN non_public BOOLEAN DEFAULT 'f';

COMMIT;
