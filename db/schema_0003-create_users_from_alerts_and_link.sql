begin;

-- create any users that don't already exist
INSERT INTO users (email)
    SELECT distinct( lower( alert.email ) ) FROM alert
        LEFT JOIN users ON lower( users.email ) = lower( alert.email )
        WHERE users.id IS NULL;

ALTER table alert
    ADD COLUMN user_id INT REFERENCES users(id);

-- populate the user ids in the alert table
UPDATE alert
    SET user_id = (
        SELECT id
        FROM users
        WHERE users.email = lower( alert.email )
    );

CREATE INDEX alert_user_id_idx on alert ( user_id );

-- tidy up now everythings in place
ALTER table alert
    ALTER COLUMN user_id SET NOT NULL;

ALTER table alert
    DROP COLUMN email;

commit;
