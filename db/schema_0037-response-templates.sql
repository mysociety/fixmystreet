create table response_templates (
    id serial not null primary key,
    body_id int references body(id) not null,
    title text not null,
    text text not null,
    created timestamp not null default current_timestamp,
    unique(body_id, title)
);
