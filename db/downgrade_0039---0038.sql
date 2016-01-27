begin;
alter table users drop column twitter_id;
alter table users drop column facebook_id;
commit;
