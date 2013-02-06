begin;

ALTER TABLE body ADD name text;
UPDATE body SET name='';
ALTER table body ALTER COLUMN name SET NOT NULL;

commit;
