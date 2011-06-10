-- link the problems to the users, creating the users as required. Removes the
-- email field from the problems.
--
-- Uses the most recently used non-anonymmous name as the name for the user.

begin;

-- create users from the problems
INSERT INTO users (email)
    SELECT distinct( lower( email ) ) FROM problem;

-- add a user id to the problems
ALTER TABLE problem
    ADD COLUMN user_id INT REFERENCES users(id);

-- populate the user_ids
update problem
    set user_id = (
        select id
        from users
        where users.email = lower( problem.email )
    );

-- create the index now that the entries have been made
create index problem_user_id_idx on problem ( user_id );

-- add names from the problems
UPDATE users
    SET name = (
        select name from problem
        where user_id = users.id
        order by created desc
        limit 1
    ),
    phone = (
        select phone from problem
        where user_id = users.id
        order by created desc
        limit 1
    );


-- make the problems user id not null etc
ALTER TABLE problem
    ALTER COLUMN user_id SET NOT NULL;

-- drop emails from the problems
ALTER TABLE problem
    DROP COLUMN email;
ALTER TABLE problem
    DROP COLUMN phone;

commit;
