BEGIN;

ALTER TABLE contacts ADD confirmed boolean;
ALTER TABLE contacts ADD deleted boolean;

UPDATE contacts SET confirmed='t', deleted='t' WHERE state = 'deleted';
UPDATE contacts SET confirmed='f', deleted='t' WHERE state = 'inactive';
UPDATE contacts SET confirmed='t', deleted='f' WHERE state = 'confirmed';
UPDATE contacts SET confirmed='f', deleted='f' WHERE state = 'unconfirmed';

ALTER TABLE contacts ALTER COLUMN confirmed SET NOT NULL;
ALTER TABLE contacts ALTER COLUMN deleted SET NOT NULL;
ALTER TABLE contacts DROP COLUMN state;

ALTER TABLE contacts_history ADD confirmed boolean;
ALTER TABLE contacts_history ADD deleted boolean;

UPDATE contacts_history SET confirmed='t', deleted='t' WHERE state = 'deleted';
UPDATE contacts_history SET confirmed='f', deleted='t' WHERE state = 'inactive';
UPDATE contacts_history SET confirmed='t', deleted='f' WHERE state = 'confirmed';
UPDATE contacts_history SET confirmed='f', deleted='f' WHERE state = 'unconfirmed';

ALTER TABLE contacts_history ALTER COLUMN confirmed SET NOT NULL;
ALTER TABLE contacts_history ALTER COLUMN deleted SET NOT NULL;
ALTER TABLE contacts_history DROP COLUMN state;

CREATE OR REPLACE FUNCTION contacts_updated()
    returns trigger as '
    begin
        insert into contacts_history (contact_id, body_id, category, email, editor, whenedited, note, confirmed, deleted) values (new.id, new.body_id, new.category, new.email, new.editor, new.whenedited, new.note, new.confirmed, new.deleted);
        return new;
    end;
' language 'plpgsql';

COMMIT;

