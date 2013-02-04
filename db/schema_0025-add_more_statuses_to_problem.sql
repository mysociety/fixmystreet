BEGIN;

    ALTER TABLE problem DROP CONSTRAINT problem_state_check;

    ALTER TABLE problem ADD CONSTRAINT problem_state_check CHECK (
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'investigating'
        or state = 'planned'
        or state = 'in progress'
        or state = 'action scheduled'
        or state = 'closed'
        or state = 'fixed'
        or state = 'fixed - council'
        or state = 'fixed - user'
        or state = 'hidden'
        or state = 'partial'
        or state = 'unable to fix'
        or state = 'not responsible'
        or state = 'duplicate'
        or state = 'internal referral'
    );


    ALTER TABLE comment DROP CONSTRAINT comment_problem_state_check;

    ALTER TABLE comment ADD CONSTRAINT comment_problem_state_check CHECK (
        problem_state = 'confirmed'
        or problem_state = 'investigating'
        or problem_state = 'planned'
        or problem_state = 'in progress'
        or problem_state = 'action scheduled'
        or problem_state = 'closed'
        or problem_state = 'fixed'
        or problem_state = 'fixed - council'
        or problem_state = 'fixed - user'
        or problem_state = 'unable to fix'
        or problem_state = 'not responsible'
        or problem_state = 'duplicate'
        or problem_state = 'internal referral'
    );

    UPDATE alert_type set item_where = 'nearby.problem_id = problem.id and problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'')'
     WHERE ref = 'postcode_local_problems';
    UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in
        (''confirmed'', ''investigating'', ''planned'', ''in progress'',
         ''fixed'', ''fixed - council'', ''fixed - user'', ''closed''
         ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
         ''internal referral'' )'
        WHERE ref = 'new_problems';
    UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in (''fixed'', ''fixed - user'', ''fixed - council'')' WHERE ref = 'new_fixed_problems';
    UPDATE alert_type set item_where = 'nearby.problem_id = problem.id and problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'')'
    WHERE ref = 'local_problems';
    UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
      ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'' ) AND
    (council like ''%''||?||''%'' or council is null) and
    areas like ''%,''||?||'',%''' WHERE ref = 'council_problems';
    UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'' ) AND
    (council like ''%''||?||''%'' or council is null) and
    areas like ''%,''||?||'',%''' WHERE ref = 'ward_problems';
    UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'' ) AND
    areas like ''%,''||?||'',%''' WHERE ref = 'area_problems';

COMMIT;
