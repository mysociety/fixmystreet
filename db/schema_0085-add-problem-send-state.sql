BEGIN;

ALTER TABLE problem ADD send_state text NOT NULL DEFAULT 'processed' CHECK (
    send_state = 'unprocessed'
    or send_state = 'processed'
    or send_state = 'skipped'
    or send_state = 'sent'
    or send_state = 'acknowledged'
);

UPDATE problem SET send_state = 'unprocessed'
    WHERE (whensent IS NULL OR send_fail_body_ids != '{}')
        AND bodies_str IS NOT NULL
        AND state IN (SELECT label FROM state WHERE type='open' UNION SELECT 'confirmed' UNION SELECT 'unconfirmed');

ALTER TABLE problem ALTER COLUMN send_state SET DEFAULT 'unprocessed';

COMMIT;

CREATE INDEX CONCURRENTLY problem_send_state_state_idx ON problem(send_state, state) WHERE state NOT IN ('unconfirmed', 'hidden', 'partial');
