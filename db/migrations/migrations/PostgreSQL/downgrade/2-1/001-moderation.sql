-- Convert schema 'db/migrations/migrations/_source/deploy/2/001-auto.yml' to 'db/migrations/migrations/_source/deploy/1/001-auto.yml':;

;
ALTER TABLE admin_log DROP COLUMN user_id;

;
ALTER TABLE admin_log DROP COLUMN reason;

;
DROP TABLE user_body_permissions;

;
DROP TABLE moderation_original_data;

;
