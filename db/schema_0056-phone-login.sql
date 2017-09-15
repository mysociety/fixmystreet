BEGIN;

ALTER TABLE users ADD email_verified boolean not null default 'f';
UPDATE USERS set email_verified = 't';
ALTER TABLE users ADD phone_verified boolean not null default 'f';

ALTER TABLE users ALTER email DROP NOT NULL;
ALTER TABLE users DROP CONSTRAINT users_email_key;
CREATE UNIQUE INDEX users_email_verified_unique ON users (email) WHERE email_verified;
CREATE UNIQUE INDEX users_phone_verified_unique ON users (phone) WHERE phone_verified;

COMMIT;
