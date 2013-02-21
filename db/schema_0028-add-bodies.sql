BEGIN;

-- Remove unused function
drop function ms_current_date();

-- Rename open311conf to create the new body table
ALTER TABLE open311conf RENAME TO body;
ALTER INDEX open311conf_pkey RENAME TO body_pkey;
ALTER INDEX open311conf_area_id_key RENAME TO body_area_id_key;
ALTER TABLE body ALTER COLUMN endpoint DROP NOT NULL;
ALTER TABLE body DROP CONSTRAINT open311conf_comment_user_id_fkey;
ALTER TABLE body ADD CONSTRAINT body_comment_user_id_fkey
    FOREIGN KEY (comment_user_id) REFERENCES users(id);
ALTER SEQUENCE open311conf_id_seq RENAME TO body_id_seq;

-- Update contacts column to be better named
ALTER TABLE contacts RENAME area_id TO body_id;
ALTER TABLE contacts_history RENAME area_id TO body_id;
ALTER INDEX contacts_area_id_category_idx RENAME TO contacts_body_id_category_idx;

-- Data migration from contacts
UPDATE body SET id = area_id;
INSERT INTO body (id, area_id)
    SELECT DISTINCT body_id, body_id FROM contacts WHERE body_id not in (SELECT id FROM body);
SELECT setval('body_id_seq', (SELECT MAX(id) FROM body) );

ALTER TABLE contacts ADD CONSTRAINT contacts_body_id_fkey
    FOREIGN KEY (body_id) REFERENCES body(id);

DROP TRIGGER contacts_update_trigger ON contacts;
DROP TRIGGER contacts_insert_trigger ON contacts;
DROP FUNCTION contacts_updated();
create function contacts_updated()
    returns trigger as '
    begin
        insert into contacts_history (contact_id, body_id, category, email, editor, whenedited, note, confirmed, deleted) values (new.id, new.body_id, new.category, new.email, new.editor, new.whenedited, new.note, new.confirmed, new.deleted);
         return new;
     end;
' language 'plpgsql';
create trigger contacts_update_trigger after update on contacts
    for each row execute procedure contacts_updated();
create trigger contacts_insert_trigger after insert on contacts
    for each row execute procedure contacts_updated();

-- Give bodies a name
ALTER TABLE body ADD name text;
UPDATE body SET name='';
ALTER table body ALTER COLUMN name SET NOT NULL;

-- Update users column to be better named
ALTER TABLE users RENAME COLUMN from_council TO from_body;
ALTER TABLE users ADD CONSTRAINT users_from_body_fkey
    FOREIGN KEY (from_body) REFERENCES body(id);

-- Rename problem's council column
ALTER TABLE problem RENAME COLUMN council TO bodies_str;

-- Update alert types that used 'council' column
UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in
(''confirmed'', ''investigating'', ''planned'', ''in progress'',
  ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
 ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
 ''internal referral'' ) AND
(bodies_str like ''%''||?||''%'' or bodies_str is null) and
areas like ''%,''||?||'',%''' WHERE ref = 'council_problems';
UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in
(''confirmed'', ''investigating'', ''planned'', ''in progress'',
 ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
 ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
 ''internal referral'' ) AND
(bodies_str like ''%''||?||''%'' or bodies_str is null) and
areas like ''%,''||?||'',%''' WHERE ref = 'ward_problems';

-- Move to many-many relationship between bodies and areas
create table body_areas (
    body_id integer not null references body(id),
    area_id integer not null
);
create unique index body_areas_body_id_area_id_idx on body_areas(body_id, area_id);
INSERT INTO body_areas (body_id, area_id)
    SELECT id, area_id FROM body;
ALTER TABLE body DROP COLUMN area_id;

-- Allow bodies to have a hierarchy
ALTER TABLE body ADD parent INTEGER REFERENCES body(id);

COMMIT;
