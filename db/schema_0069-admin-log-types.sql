BEGIN;

ALTER TABLE admin_log DROP CONSTRAINT admin_log_object_type_check;

ALTER TABLE admin_log ADD CONSTRAINT admin_log_object_type_check CHECK (
    object_type = 'problem'
    OR object_type = 'update'
    OR object_type = 'user'
    OR object_type = 'moderation'
    OR object_type = 'template'
    OR object_type = 'body'
    OR object_type = 'category'
    OR object_type = 'role'
);

COMMIT;

