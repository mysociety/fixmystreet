begin;
alter table users add column is_superuser boolean not null default 'f';
commit;
