begin;

alter table problem add bodies_missing text;

update problem
    set bodies_missing = split_part(bodies_str, '|', 2),
        bodies_str = split_part(bodies_str, '|', 1)
    where bodies_str like '%|%';

create index problem_bodies_str_array_idx on problem USING gin(regexp_split_to_array(bodies_str, ','));

UPDATE alert_type set item_where =
    'problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
      ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'' ) AND
    regexp_split_to_array(bodies_str, '','') && ARRAY[?]'
    WHERE ref = 'council_problems';

UPDATE alert_type set item_where =
    'problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'' ) AND
    (regexp_split_to_array(bodies_str, '','') && ARRAY[?] or bodies_str is null) and
    areas like ''%,''||?||'',%'''
    WHERE ref = 'ward_problems';

commit;
