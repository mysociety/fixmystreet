-- was created in previous versions of this branch
DROP TABLE IF EXISTS moderation_log;

BEGIN;

alter table admin_log add column
    user_id int references users(id) null;

alter table admin_log add column
    reason text not null default '';

create table moderation_original_data (
    id serial not null primary key,

    -- Problem details
    problem_id int references problem(id) ON DELETE CASCADE not null,
    comment_id int references comment(id) ON DELETE CASCADE unique,

    title text null,
    detail text null, -- or text for comment
    photo bytea,
    anonymous bool not null,

    -- Metadata
    created timestamp not null default ms_current_timestamp()
);

create table user_body_permissions (
    id serial not null primary key,
    user_id int references users(id) not null,
    body_id int references body(id) not null,
    permission_type text not null check(
        permission_type='moderate' or
        -- for future expansion --
        permission_type='admin'
    ),
    unique(user_id, body_id, permission_type)
);

COMMIT;
