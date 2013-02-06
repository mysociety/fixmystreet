begin;

ALTER TABLE users ADD CONSTRAINT users_from_body_fkey
    FOREIGN KEY (from_body) REFERENCES body(id);

commit;
