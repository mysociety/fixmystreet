BEGIN;

DELETE FROM admin_log WHERE object_type = 'moderation';

ALTER TABLE admin_log DROP CONSTRAINT admin_log_object_type_check;

ALTER TABLE admin_log ADD CONSTRAINT admin_log_object_type_check CHECK (
    object_type = 'problem'
    OR object_type = 'update'
    OR object_type = 'user'
);

COMMIT;

