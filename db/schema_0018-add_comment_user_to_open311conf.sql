begin;

ALTER TABLE open311conf
    ADD COLUMN comment_user_id INT REFERENCES users(id);

commit;
