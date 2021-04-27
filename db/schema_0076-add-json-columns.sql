ALTER TABLE users ADD COLUMN extra_json jsonb;
ALTER TABLE body ADD COLUMN extra_json jsonb;
ALTER TABLE contacts ADD COLUMN extra_json jsonb;
ALTER TABLE problem ADD COLUMN extra_json jsonb;
ALTER TABLE problem ADD COLUMN geocode_json jsonb;
ALTER TABLE comment ADD COLUMN extra_json jsonb;
ALTER TABLE moderation_original_data ADD COLUMN extra_json jsonb;
ALTER TABLE defect_types ADD COLUMN extra_json jsonb;
ALTER TABLE report_extra_fields ADD COLUMN extra_json jsonb;
ALTER TABLE token ADD COLUMN data_json jsonb;

ALTER TABLE token ADD CONSTRAINT token_data_not_null CHECK (data_json IS NOT NULL) NOT VALID;
