BEGIN;

ALTER TABLE contacts ADD state text;

ALTER TABLE contacts ADD CONSTRAINT contacts_state_check CHECK (
    state = 'unconfirmed'
    or state = 'confirmed'
    or state = 'inactive'
    or state = 'deleted'
);

UPDATE contacts SET state = 'deleted' WHERE deleted;
UPDATE contacts SET state = 'confirmed' WHERE confirmed AND NOT deleted;
UPDATE contacts SET state = 'unconfirmed' WHERE NOT confirmed AND NOT deleted;

ALTER TABLE contacts ALTER COLUMN state SET NOT NULL;
ALTER TABLE contacts DROP COLUMN confirmed;
ALTER TABLE contacts DROP COLUMN deleted;

ALTER TABLE contacts_history ADD state text;

ALTER TABLE contacts_history ADD CONSTRAINT contacts_history_state_check CHECK (
    state = 'unconfirmed'
    or state = 'confirmed'
    or state = 'inactive'
    or state = 'deleted'
);

UPDATE contacts_history SET state = 'deleted' WHERE deleted;
UPDATE contacts_history SET state = 'confirmed' WHERE confirmed AND NOT deleted;
UPDATE contacts_history SET state = 'unconfirmed' WHERE NOT confirmed AND NOT deleted;

ALTER TABLE contacts_history ALTER COLUMN state SET NOT NULL;
ALTER TABLE contacts_history DROP COLUMN confirmed;
ALTER TABLE contacts_history DROP COLUMN deleted;

CREATE OR REPLACE FUNCTION contacts_updated()
    returns trigger as '
    begin
        insert into contacts_history (contact_id, body_id, category, email, editor, whenedited, note, state) values (new.id, new.body_id, new.category, new.email, new.editor, new.whenedited, new.note, new.state);
        return new;
    end;
' language 'plpgsql';

COMMIT;
