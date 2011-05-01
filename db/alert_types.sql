-- New updates on a particular problem report
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_updates', 'select * from problem where id=?', 'problem',
    'Updates on {{title}}', '/', 'Updates on {{title}}',
    'comment', 'comment.state=''confirmed''', 'created desc',
    'Update by {{name}}', '/report/{{problem_id}}#comment_{{id}}', '{{text}}', 'alert-update');

-- New problems anywhere on the site
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_problems', '', '',
    'New problems on FixMyStreet', '/', 'The latest problems reported by users',
    'problem', 'problem.state in (''confirmed'', ''fixed'')', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem');

-- New fixed problems anywhere on the site
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_fixed_problems', '', '',
    'Problems recently reported fixed on FixMyStreet', '/', 'The latest problems reported fixed by users',
    'problem', 'problem.state in (''fixed'')', 'lastupdate desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem');

-- New problems around a location
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('local_problems', '', '',
    'New local problems on FixMyStreet', '/', 'The latest local problems reported by users',
    'problem_find_nearby(?, ?, ?) as nearby,problem', 'nearby.problem_id = problem.id and problem.state in (''confirmed'', ''fixed'')', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem-nearby');

-- New problems around a location
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('local_problems_state', '', '',
    'New local problems on FixMyStreet', '/', 'The latest local problems reported by users',
    'problem_find_nearby(?, ?, ?) as nearby,problem', 'nearby.problem_id = problem.id and problem.state in (?)', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem-nearby');

-- New problems around a postcode
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('postcode_local_problems', '', '',
    'New problems near {{POSTCODE}} on FixMyStreet', '/', 'The latest local problems reported by users',
    'problem_find_nearby(?, ?, ?) as nearby,problem', 'nearby.problem_id = problem.id and problem.state in (''confirmed'', ''fixed'')', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem-nearby');

-- New problems around a postcode with a particular state
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('postcode_local_problems_state', '', '',
    'New problems NEAR {{POSTCODE}} on FixMyStreet', '/', 'The latest local problems reported by users',
    'problem_find_nearby(?, ?, ?) as nearby,problem', 'nearby.problem_id = problem.id and problem.state in (?)', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem-nearby');

-- New problems sent to a particular council
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('council_problems', '', '',
    'New problems to {{COUNCIL}} on FixMyStreet', '/reports', 'The latest problems for {{COUNCIL}} reported by users',
    'problem', 'problem.state in (''confirmed'', ''fixed'') and (council like ''%''||?||''%''
        or council is null) and areas like ''%,''||?||'',%''', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem-council'
);

-- New problems within a particular ward sent to a particular council
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('ward_problems', '', '',
    'New problems for {{COUNCIL}} within {{WARD}} ward on FixMyStreet', '/reports',
    'The latest problems for {{COUNCIL}} within {{WARD}} ward reported by users',
    'problem', 'problem.state in (''confirmed'', ''fixed'') and (council like ''%''||?||''%''
        or council is null) and areas like ''%,''||?||'',%''', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem-ward'
);

-- New problems within a particular voting area (ward, constituency, whatever)
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('area_problems', '', '',
    'New problems within {{NAME}}''s boundary on FixMyStreet', '/reports',
    'The latest problems within {{NAME}}''s boundary reported by users', 'problem',
    'problem.state in (''confirmed'', ''fixed'') and areas like ''%,''||?||'',%''', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'alert-problem-area'
);


-- Generic problem search using the Open311 API
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link,
    head_description,
    item_table,
    item_where, item_order,
    item_title, item_link, item_description,
    template)
values ('open311_requests_rss', '', '',
    'Open311 requests search on FixMyStreet', '/open311',
    'Open311 search on requests',
    'problem',
    'problem.state in (''confirmed'', ''fixed'')', 'updated_datetime desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}',
     ''
);
