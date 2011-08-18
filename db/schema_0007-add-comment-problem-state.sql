begin;

    ALTER TABLE comment ADD column problem_state text;

    ALTER TABLE comment ADD CONSTRAINT comment_problem_state_check CHECK ( 
        problem_state = 'confirmed'
        or problem_state = 'investigating'
        or problem_state = 'planned'
        or problem_state = 'in progress'
        or problem_state = 'closed'
        or problem_state = 'fixed'
        or problem_state = 'fixed - council'
        or problem_state = 'fixed - user'
    );

commit;
