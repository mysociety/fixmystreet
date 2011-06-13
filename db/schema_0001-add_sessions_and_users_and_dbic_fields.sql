-- These are changes needed to the schema to support moving over to DBIx::Class

begin;

-- table for sessions - needed by Catalyst::Plugin::Session::Store::DBIC
CREATE TABLE sessions (
    id           CHAR(72) PRIMARY KEY,
    session_data TEXT,
    expires      INTEGER
);

-- users table
create table users (
    id              serial  not null primary key,
    email           text    not null unique,
    name            text,
    phone           text,
    password        text    not null default ''
);

--- add PK to contacts table
ALTER TABLE contacts
    ADD COLUMN id SERIAL PRIMARY KEY;

AlTER TABLE contacts_history
    ADD COLUMN contact_id integer;

update contacts_history
    set contact_id = (
        select id
        from contacts
        where contacts_history.category = contacts.category
          and contacts_history.area_id = contacts.area_id
    );

-- Note any categories that have been deleted will cause the following
-- line to fail, and they'll need to be deleted manually first.

AlTER TABLE contacts_history
    alter COLUMN contact_id SET NOT NULL;
    
create or replace function contacts_updated()
    returns trigger as '
    begin
        insert into contacts_history (contact_id, area_id, category, email, editor, whenedited, note, confirmed, deleted) values (new.id, new.area_id, new.category, new.email, new.editor, new.whenedited, new.note, new.confirmed, new.deleted);
        return new;
    end;
' language 'plpgsql';


--- add pk and lowercase check to abuse
drop index  abuse_email_idx;
update abuse set email = lower(email);
alter table abuse add check( lower(email) = email );
alter table abuse add primary key(email);

commit;
