-- Zurich would like to update the detail text of a whole bunch
-- of reports on the site. They've provided a CSV file with the report id
-- and the new detail text for the reports in question.
-- This script applies the new details to the database
-- from the file 'report_updates.txt'. This file must be stripped
-- of its header row or errors will occur.
BEGIN;

CREATE TEMP TABLE report_updates (id int, detail text);

\copy report_updates FROM 'report_updates.txt' WITH (FORMAT CSV)

UPDATE problem
SET detail = report_updates.detail
FROM report_updates
WHERE problem.id = report_updates.id
-- Only update a report if its detail field has actually changed:
AND problem.detail != report_updates.detail;


DROP TABLE report_updates;

COMMIT;
