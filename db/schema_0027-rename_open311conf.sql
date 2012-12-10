begin;

ALTER TABLE open311conf RENAME TO body;
ALTER INDEX open311conf_pkey RENAME TO body_pkey;
ALTER INDEX open311conf_area_id_key RENAME TO body_area_id_key;
ALTER TABLE body ALTER COLUMN endpoint DROP NOT NULL;
ALTER TABLE body DROP CONSTRAINT open311conf_comment_user_id_fkey;
ALTER TABLE body ADD CONSTRAINT body_comment_user_id_fkey
    FOREIGN KEY (comment_user_id) REFERENCES users(id);
ALTER SEQUENCE open311conf_id_seq RENAME TO body_id_seq;

commit;
