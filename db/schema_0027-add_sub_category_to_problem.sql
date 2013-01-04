begin;

ALTER TABLE problem
    ADD COLUMN subcategory TEXT;

commit;
