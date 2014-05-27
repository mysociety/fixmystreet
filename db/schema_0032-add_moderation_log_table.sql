-- Record basic information about edits made through moderation interface
create table moderation_log (
    id serial not null primary key,

    -- Problem details
    user_id int references users(id) not null,
    problem_id int references problem(id) not null,
    comment_id int references comment(id),

    -- Metadata
    created timestamp not null default ms_current_timestamp(),
    reason text,

    moderation_object text not null check (
      moderation_object = 'problem'
      or (moderation_object = 'comment' and comment_id is not null)
    ),

    moderation_type text not null check(
        moderation_type='hide' or 
        moderation_type='title' or
        moderation_type='detail' or
        moderation_type='photo' or
        moderation_type='anonymous'
    ),

    whenedited timestamp not null default ms_current_timestamp()
);

create table moderation_original_data (
    id serial not null primary key,

    -- Problem details
    problem_id int references problem(id) not null,
    comment_id int references comment(id),

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
