BEGIN;

DROP INDEX user_planned_reports_report_id_idx;
DROP INDEX user_planned_reports_user_id_idx;

DROP INDEX user_roles_role_id_idx;
DROP INDEX user_roles_user_id_idx;

DROP INDEX users_from_body_idx;

COMMIT;
