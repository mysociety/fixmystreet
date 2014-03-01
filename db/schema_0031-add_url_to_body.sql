BEGIN;

-- `external_url' includes an URL for reporting problems to the body directly.
-- It can be displayed in the new report form when no contacts are set; see
-- templates/web/fixamingata/report/new/councils_text_none.html for an example.

ALTER TABLE body ADD external_url TEXT;

COMMIT;
