begin;

    ALTER TABLE problem DROP CONSTRAINT problem_state_check;

    ALTER TABLE problem ADD CONSTRAINT problem_state_check CHECK ( 
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'investigating'
        or state = 'planned'
        or state = 'in progress'
        or state = 'closed'
        or state = 'fixed'
        or state = 'fixed - council'
        or state = 'fixed - user'
        or state = 'hidden'
        or state = 'partial'
    );

commit;
