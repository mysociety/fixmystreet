BEGIN;

UPDATE alert_type SET head_title = replace(head_title, '{{SITE_NAME}}', 'FixMyStreet');

COMMIT;
