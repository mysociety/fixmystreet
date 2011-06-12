begin;

-- create any users that don't already exist
INSERT INTO users (email)
    SELECT distinct( lower( comment.email ) ) FROM comment 
        LEFT JOIN users ON lower( users.email ) = lower( comment.email )
        WHERE users.id IS NULL;

ALTER table comment
    ADD COLUMN user_id INT REFERENCES users(id);

-- populate the user ids in the comment table
UPDATE comment
    SET user_id = (
        SELECT id
        FROM users
        WHERE users.email = lower( comment.email )
    );

CREATE INDEX comment_user_id_idx on comment ( user_id );

UPDATE users
    SET name = (
        select name from comment
        where user_id = users.id
        order by created desc
        limit 1
    )
WHERE users.name IS NULL;

-- set up the anonymous flag
ALTER table comment
    ADD COLUMN anonymous BOOL;

UPDATE comment SET anonymous = false WHERE name <> '';

UPDATE comment SET anonymous = true  WHERE anonymous is NULL;

-- tidy up now everythings in place
ALTER table comment
    ALTER COLUMN user_id SET NOT NULL;

ALTER table comment
    ALTER COLUMN anonymous SET NOT NULL;

ALTER table comment
    DROP COLUMN email;

commit;
