alter table problem add send_state text not null default 'processed' check (
    send_state = 'unprocessed'
    or send_state = 'processed'
    or send_state = 'skipped'
    or send_state = 'sent'
    or send_state = 'acknowledged'
);

UPDATE problem SET send_state = 'unprocessed'
    WHERE (whensent IS NULL OR send_fail_body_ids != '{}')
        AND bodies_str IS NOT NULL
        AND state IN (SELECT label FROM state WHERE type='open' UNION SELECT 'confirmed');

alter table problem alter column send_state set default 'unprocessed';

create index concurrently problem_state_send_state_idx on problem(state, send_state);
