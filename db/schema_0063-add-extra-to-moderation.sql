BEGIN;

ALTER TABLE moderation_original_data ADD extra text;
ALTER TABLE moderation_original_data ADD category text;
ALTER TABLE moderation_original_data ADD latitude double precision;
ALTER TABLE moderation_original_data ADD longitude double precision;

COMMIT;

