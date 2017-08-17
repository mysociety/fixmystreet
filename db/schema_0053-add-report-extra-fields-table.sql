BEGIN;

CREATE TABLE report_extra_fields (
    id serial not null primary key,
    name text not null,
    cobrand text,
    language text,
    extra text
);

COMMIT;
