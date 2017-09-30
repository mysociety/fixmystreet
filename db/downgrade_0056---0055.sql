BEGIN;

ALTER TABLE users DROP email_verified;
ALTER TABLE users DROP phone_verified;

DELETE FROM users WHERE email IS NULL;
ALTER TABLE users ALTER email SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_email_key UNIQUE (email);

COMMIT;
