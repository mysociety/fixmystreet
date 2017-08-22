BEGIN;

DROP TABLE state;

ALTER TABLE problem ADD CONSTRAINT problem_state_check CHECK (
    state = 'unconfirmed'
    or state = 'hidden'
    or state = 'partial'
    or state = 'confirmed'
    or state = 'investigating'
    or state = 'planned'
    or state = 'in progress'
    or state = 'action scheduled'
    or state = 'fixed'
    or state = 'fixed - council'
    or state = 'fixed - user'
    or state = 'closed'
    or state = 'unable to fix'
    or state = 'not responsible'
    or state = 'duplicate'
    or state = 'internal referral'
);
ALTER TABLE comment ADD CONSTRAINT comment_problem_state_check CHECK (
    problem_state = 'confirmed'
    or problem_state = 'investigating'
    or problem_state = 'planned'
    or problem_state = 'in progress'
    or problem_state = 'action scheduled'
    or problem_state = 'fixed'
    or problem_state = 'fixed - council'
    or problem_state = 'fixed - user'
    or problem_state = 'closed'
    or problem_state = 'unable to fix'
    or problem_state = 'not responsible'
    or problem_state = 'duplicate'
    or problem_state = 'internal referral'
);

COMMIT;
