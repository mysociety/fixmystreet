BEGIN;

ALTER TABLE problem DROP CONSTRAINT problem_cobrand_check;
ALTER TABLE problem DROP CONSTRAINT problem_cobrand_data_check;
ALTER TABLE comment DROP CONSTRAINT comment_cobrand_check;
ALTER TABLE comment DROP CONSTRAINT comment_cobrand_data_check;
ALTER TABLE alert DROP CONSTRAINT alert_cobrand_check;
ALTER TABLE alert DROP CONSTRAINT alert_cobrand_data_check;

ALTER TABLE problem ADD CONSTRAINT problem_cobrand_check CHECK (cobrand ~* '^[a-z0-9_]*$');
ALTER TABLE problem ADD CONSTRAINT problem_cobrand_data_check CHECK (cobrand_data ~* '^[a-z0-9_]*$');
ALTER TABLE comment ADD CONSTRAINT comment_cobrand_check CHECK (cobrand ~* '^[a-z0-9_]*$');
ALTER TABLE comment ADD CONSTRAINT comment_cobrand_data_check CHECK (cobrand_data ~* '^[a-z0-9_]*$');
ALTER TABLE alert ADD CONSTRAINT alert_cobrand_check CHECK (cobrand ~* '^[a-z0-9_]*$');
ALTER TABLE alert ADD CONSTRAINT alert_cobrand_data_check CHECK (cobrand_data ~* '^[a-z0-9_]*$');

COMMIT;
