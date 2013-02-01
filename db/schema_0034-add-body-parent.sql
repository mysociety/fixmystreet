begin;

ALTER TABLE body ADD parent INTEGER REFERENCES body(id);

commit;
