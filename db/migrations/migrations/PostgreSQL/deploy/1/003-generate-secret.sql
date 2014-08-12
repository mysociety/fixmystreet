-- assumes there's a secret table (from the schema.sql)
-- use your own secret if you have one :-)
-- otherwise you can use this to populate the secret table with a random secret

-- empty the table in case it has a value already (i.e., this is *destructive*!)
delete from secret;

insert into secret values (md5(random()::text));
