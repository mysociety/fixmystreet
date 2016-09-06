BEGIN;

CREATE TABLE response_priorities (
    id serial not null primary key,
    body_id int references body(id) not null,
    name text not null,
    deleted boolean not null default 'f',
    unique(body_id, name)
);

CREATE TABLE contact_response_priorities (
    id serial NOT NULL PRIMARY KEY,
    contact_id int REFERENCES contacts(id) NOT NULL,
    response_priority_id int REFERENCES response_priorities(id) NOT NULL
);

ALTER TABLE problem
    ADD COLUMN response_priority_id int REFERENCES response_priorities(id);

COMMIT;
