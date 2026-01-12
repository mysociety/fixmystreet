CREATE INDEX concurrently user_planned_reports_report_id_idx ON user_planned_reports(report_id);
CREATE INDEX concurrently user_planned_reports_user_id_idx ON user_planned_reports(user_id);

CREATE INDEX concurrently user_roles_role_id_idx ON user_roles(role_id);
CREATE INDEX concurrently user_roles_user_id_idx ON user_roles(user_id);

CREATE INDEX concurrently users_from_body_idx ON users (from_body) WHERE from_body IS NOT NULL;
