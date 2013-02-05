BEGIN;

    UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
      ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'' ) AND
    (bodies_str like ''%''||?||''%'' or bodies_str is null) and
    areas like ''%,''||?||'',%''' WHERE ref = 'council_problems';

    UPDATE alert_type set item_where = 'problem.non_public = ''f'' and problem.state in
    (''confirmed'', ''investigating'', ''planned'', ''in progress'',
     ''fixed'', ''fixed - council'', ''fixed - user'', ''closed'',
     ''action scheduled'', ''not responsible'', ''duplicate'', ''unable to fix'',
     ''internal referral'' ) AND
    (bodies_str like ''%''||?||''%'' or bodies_str is null) and
    areas like ''%,''||?||'',%''' WHERE ref = 'ward_problems';

COMMIT;
