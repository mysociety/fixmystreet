begin;
alter table users add column oidc_ids text ARRAY;
commit;
