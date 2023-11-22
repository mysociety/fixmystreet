ALTER TABLE problem DROP CONSTRAINT problem_send_state_check;
ALTER TABLE problem ADD CONSTRAINT problem_send_state_check CHECK (
    send_state = 'unprocessed'
    or send_state = 'processed'
    or send_state = 'skipped'
    or send_state = 'sent'
    or send_state = 'acknowledged'
);
ALTER TABLE comment DROP CONSTRAINT comment_send_state_check;
ALTER TABLE comment ADD CONSTRAINT comment_send_state_check CHECK (
    send_state = 'unprocessed'
    or send_state = 'processed'
    or send_state = 'skipped'
    or send_state = 'sent'
);

