begin;

create table body_areas (
    body_id integer not null references body(id),
    area_id integer not null
);
create unique index body_areas_body_id_area_id_idx on body_areas(body_id, area_id);

INSERT INTO body_areas (body_id, area_id)
    SELECT id, area_id FROM body;

ALTER TABLE body DROP COLUMN area_id;

commit;

