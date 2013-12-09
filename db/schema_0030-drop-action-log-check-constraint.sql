BEGIN;

ALTER TABLE admin_log 
    DROP CONSTRAINT admin_log_action_check;

COMMIT;
