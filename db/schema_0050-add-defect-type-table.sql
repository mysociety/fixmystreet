BEGIN;

CREATE TABLE defect_types (
    id serial not null primary key,
    body_id int references body(id) not null,
    name text not null,
    description text not null,
    extra text,
    unique(body_id, name)
);

CREATE TABLE contact_defect_types (
    id serial NOT NULL PRIMARY KEY,
    contact_id int REFERENCES contacts(id) NOT NULL,
    defect_type_id int REFERENCES defect_types(id) NOT NULL
);

ALTER TABLE problem
    ADD COLUMN defect_type_id int REFERENCES defect_types(id);

COMMIT;
