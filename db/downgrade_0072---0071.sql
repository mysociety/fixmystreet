BEGIN;

ALTER TABLE contacts DROP CONSTRAINT contacts_state_check;

ALTER TABLE contacts ADD CONSTRAINT contacts_state_check CHECK (
    state = 'unconfirmed'
    or state = 'confirmed'
    or state = 'inactive'
    or state = 'deleted'
);

ALTER TABLE contacts_history DROP CONSTRAINT contacts_history_state_check;

ALTER TABLE contacts_history ADD CONSTRAINT contacts_history_state_check CHECK (
    state = 'unconfirmed'
    or state = 'confirmed'
    or state = 'inactive'
    or state = 'deleted'
);

COMMIT;
