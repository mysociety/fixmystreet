BEGIN;

CREATE TABLE state (
    id serial not null primary key,
    label text not null unique,
    type text not null check (type = 'open' OR type = 'closed'),
    name text not null unique
);

ALTER TABLE problem DROP CONSTRAINT problem_state_check;
ALTER TABLE comment DROP CONSTRAINT comment_problem_state_check;

UPDATE alert_type SET item_where = 'nearby.problem_id = problem.id
    and problem.non_public = ''f''
    and problem.state NOT IN (''hidden'', ''unconfirmed'', ''partial'')'
    WHERE ref = 'postcode_local_problems';
UPDATE alert_type set item_where = 'problem.non_public = ''f''
    and problem.state NOT IN (''hidden'', ''unconfirmed'', ''partial'')'
    WHERE ref = 'new_problems';
UPDATE alert_type set item_where = 'problem.non_public = ''f''
    and problem.state in (''fixed'', ''fixed - user'', ''fixed - council'')'
    WHERE ref = 'new_fixed_problems';
UPDATE alert_type set item_where = 'nearby.problem_id = problem.id
    and problem.non_public = ''f''
    and problem.state NOT IN (''hidden'', ''unconfirmed'', ''partial'')'
    WHERE ref = 'local_problems';
UPDATE alert_type set item_where = 'problem.non_public = ''f''
    AND problem.state NOT IN (''hidden'', ''unconfirmed'', ''partial'')
    AND regexp_split_to_array(bodies_str, '','') && ARRAY[?]'
    WHERE ref = 'council_problems';
UPDATE alert_type set item_where = 'problem.non_public = ''f''
    AND problem.state NOT IN (''hidden'', ''unconfirmed'', ''partial'')
    AND (regexp_split_to_array(bodies_str, '','') && ARRAY[?] or bodies_str is null) and
    areas like ''%,''||?||'',%'''
    WHERE ref = 'ward_problems';
UPDATE alert_type set item_where = 'problem.non_public = ''f''
    AND problem.state NOT IN (''hidden'', ''unconfirmed'', ''partial'')
    AND areas like ''%,''||?||'',%'''
    WHERE ref = 'area_problems';

COMMIT;
