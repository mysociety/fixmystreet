BEGIN;

ALTER TABLE moderation_original_data DROP extra;
ALTER TABLE moderation_original_data DROP latitude;
ALTER TABLE moderation_original_data DROP longitude;
ALTER TABLE moderation_original_data DROP category;

COMMIT;
