-- New updates on a particular problem report
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_updates', 'select * from problem where id=?', 'problem',
    'Updates on {{title}}', '/', 'Updates on {{title}}',
    'comment', 'comment.state=\'confirmed\'', 'created desc',
    'Update by {{name}}', '/report/{{problem_id}}#comment_{{id}}', '{{text}}', 'eha/alert-update');

-- New problems anywhere on the site
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_problems', '', '',
    'New reports on reportemptyhomes.com', '/', 'The latest empty properties reported by users',
    'problem', 'problem.state in (\'confirmed\', \'fixed\')', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'eha/alert-problem');

-- New fixed problems anywhere on the site
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_fixed_problems', '', '',
    'Properties recently reported as put back to use on reportemptyhomes.com', '/', 'The latest properties reported back to use by users',
    'problem', 'problem.state in (\'fixed\')', 'lastupdate desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'eha/alert-problem');

-- New problems around a location
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('local_problems', '', '',
    'New local reports on reportemptyhomes.com', '/', 'The latest local reports reported by users',
    'problem_find_nearby(?, ?, ?) as nearby,problem', 'nearby.problem_id = problem.id and problem.state in (\'confirmed\', \'fixed\')', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'eha/alert-problem-nearby');

-- New problems sent to a particular council
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('council_problems', '', '',
    'New reports to {{COUNCIL}} on reportemptyhomes.com', '/reports', 'The latest reports for {{COUNCIL}} reported by users',
    'problem', 'problem.state in (\'confirmed\', \'fixed\') and (council like \'%\'||?||\'%\'
        or council is null) and areas like \'%,\'||?||\',%\'', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'eha/alert-problem-council'
);

-- New problems within a particular ward sent to a particular council
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('ward_problems', '', '',
    'New reports for {{COUNCIL}} within {{WARD}} ward on reportemptyhomes.com', '/reports',
    'The latest reports for {{COUNCIL}} within {{WARD}} ward reported by users',
    'problem', 'problem.state in (\'confirmed\', \'fixed\') and (council like \'%\'||?||\'%\'
        or council is null) and areas like \'%,\'||?||\',%\'', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'eha/alert-problem-ward'
);

-- New problems within a particular voting area (ward, constituency, whatever)
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('area_problems', '', '',
    'New reports within {{NAME}}\'s boundary on reportemptyhomes.com', '/reports',
    'The latest reports within {{NAME}}\'s boundary reported by users', 'problem',
    'problem.state in (\'confirmed\', \'fixed\') and areas like \'%,\'||?||\',%\'', 'created desc',
    '{{title}}, {{confirmed}}', '/report/{{id}}', '{{detail}}', 'eha/alert-problem-area'
);

