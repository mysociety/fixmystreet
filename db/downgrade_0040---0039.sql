begin;
alter table users drop column is_superuser;
commit;
