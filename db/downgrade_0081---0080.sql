BEGIN;

ALTER TABLE alert_sent
    DROP CONSTRAINT alert_sent_alert_id_fkey,
    ADD CONSTRAINT alert_sent_alert_id_fkey
        FOREIGN KEY (alert_id)
        REFERENCES alert(id)
        NOT VALID;

ALTER TABLE alert_sent
    VALIDATE CONSTRAINT alert_sent_alert_id_fkey;

ALTER TABLE user_planned_reports
    DROP CONSTRAINT user_planned_reports_report_id_fkey,
    ADD CONSTRAINT user_planned_reports_report_id_fkey
        FOREIGN KEY (report_id)
        REFERENCES problem(id)
        NOT VALID;

ALTER TABLE user_planned_reports
    VALIDATE CONSTRAINT user_planned_reports_report_id_fkey;

ALTER TABLE user_planned_reports
    DROP CONSTRAINT user_planned_reports_user_id_fkey,
    ADD CONSTRAINT user_planned_reports_user_id_fkey
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        NOT VALID;

ALTER TABLE user_planned_reports
    VALIDATE CONSTRAINT user_planned_reports_user_id_fkey;

COMMIT;
