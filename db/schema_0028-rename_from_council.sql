begin;

ALTER TABLE users RENAME COLUMN from_council TO from_body;

commit;
