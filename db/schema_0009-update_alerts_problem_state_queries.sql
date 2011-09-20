begin;

    UPDATE alert_type set item_where = 'nearby.problem_id = problem.id and problem.state in 
    (''confirmed'', ''investigating'', ''planned'', ''in progress'', 
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'')' WHERE ref = 'postcode_local_problems';
    UPDATE alert_type set item_where = 'problem.state in 
        (''confirmed'', ''investigating'', ''planned'', ''in progress'', 
         ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'' )' WHERE ref = 'new_problems';
    UPDATE alert_type set item_where = 'problem.state in (''fixed'', ''fixed - user'', ''fixed - council'')' WHERE ref = 'new_fixed_problems';
    UPDATE alert_type set item_where = 'nearby.problem_id = problem.id and problem.state in 
    (''confirmed'', ''investigating'', ''planned'', ''in progress'', 
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'')' WHERE ref = 'local_problems';
    UPDATE alert_type set item_where = 'problem.state in 
    (''confirmed'', ''investigating'', ''planned'', ''in progress'', 
      ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'') and 
    (council like ''%''||?||''%'' or council is null) and 
    areas like ''%,''||?||'',%''' WHERE ref = 'council_problems';
    UPDATE alert_type set item_where = 'problem.state in 
    (''confirmed'', ''investigating'', ''planned'', ''in progress'', 
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'') and 
    (council like ''%''||?||''%'' or council is null) and 
    areas like ''%,''||?||'',%''' WHERE ref = 'ward_problems';
    UPDATE alert_type set item_where = 'problem.state in 
    (''confirmed'', ''investigating'', ''planned'', ''in progress'', 
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'') and 
    areas like ''%,''||?||'',%''' WHERE ref = 'area_problems';

commit;
