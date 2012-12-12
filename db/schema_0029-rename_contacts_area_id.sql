begin;

ALTER TABLE contacts RENAME area_id TO body_id;
ALTER TABLE contacts_history RENAME area_id TO body_id;
ALTER INDEX contacts_area_id_category_idx RENAME TO contacts_body_id_category_idx;

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

commit;
