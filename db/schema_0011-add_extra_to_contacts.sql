begin;

ALTER TABLE contacts
    ADD COLUMN extra TEXT;

commit;
