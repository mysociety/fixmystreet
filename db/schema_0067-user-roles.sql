BEGIN;

-- roles table
create table roles (
    id              serial  not null primary key,
    body_id         integer not null references body(id) ON DELETE CASCADE,
    name            text,
    permissions     text ARRAY,
    unique(body_id, name)
);

-- Record which role(s) each user holds
create table user_roles (
    id              serial  not null primary key,
    role_id         integer not null references roles(id) ON DELETE CASCADE,
    user_id         integer not null references users(id) ON DELETE CASCADE
);

COMMIT;
