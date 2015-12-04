begin;
alter table users add column twitter_id bigint unique;
alter table users add column facebook_id bigint unique;
commit;
