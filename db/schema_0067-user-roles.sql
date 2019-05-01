BEGIN;

-- roles table
create table roles (
    id              serial  not null primary key,
    body_id         integer not null references body(id),
    name            text,
    permissions     text ARRAY
);

-- Record which role(s) each user holds
create table user_roles (
    id              serial  not null primary key,
    role_id         integer not null references roles(id),
    user_id         integer not null references users(id)
);

COMMIT;
