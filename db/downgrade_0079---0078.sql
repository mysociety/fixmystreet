begin;
alter table response_templates drop email_text;
alter table comment drop private_email_text;
commit;
