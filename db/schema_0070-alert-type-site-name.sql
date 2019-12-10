BEGIN;

UPDATE alert_type SET head_title = replace(head_title, 'FixMyStreet', '{{SITE_NAME}}');

COMMIT;
