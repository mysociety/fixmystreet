begin;

create table user_planned_reports (
    id serial not null primary key,
    user_id int references users(id) not null,
    report_id int references problem(id) not null,
    added timestamp not null default current_timestamp,
    removed timestamp
);

commit;
