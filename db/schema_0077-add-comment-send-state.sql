alter table comment add send_state text not null default 'processed' check (
    send_state = 'unprocessed'
    or send_state = 'processed'
    or send_state = 'skipped'
    or send_state = 'sent'
);
alter table comment alter column send_state set default 'unprocessed';
create index concurrently comment_state_send_state_idx on comment(state, send_state);
