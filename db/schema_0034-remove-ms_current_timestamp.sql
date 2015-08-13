begin;

drop table debugdate;

ALTER TABLE problem ALTER COLUMN created SET DEFAULT current_timestamp;
ALTER TABLE problem ALTER COLUMN lastupdate SET DEFAULT current_timestamp;
ALTER TABLE comment ALTER COLUMN created SET DEFAULT current_timestamp;
ALTER TABLE token ALTER COLUMN created SET DEFAULT current_timestamp;
ALTER TABLE alert ALTER COLUMN whensubscribed SET DEFAULT current_timestamp;
ALTER TABLE alert_sent ALTER COLUMN whenqueued SET DEFAULT current_timestamp;
ALTER TABLE admin_log ALTER COLUMN whenedited SET DEFAULT current_timestamp;
ALTER TABLE moderation_original_data ALTER COLUMN created SET DEFAULT current_timestamp;

drop function ms_current_timestamp();

commit;
