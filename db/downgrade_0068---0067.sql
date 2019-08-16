begin;
alter table users drop column oidc_ids;
commit;
