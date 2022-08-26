ALTER TABLE token VALIDATE CONSTRAINT token_data_not_null;
ALTER TABLE token DROP CONSTRAINT token_data_not_null;
ALTER TABLE token ALTER COLUMN data_json SET NOT NULL;
