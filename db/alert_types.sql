-- New updates on a particular problem report
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_updates', 'select * from problem where id=?', 'problem',
    'Updates on {{title}}', '/', 'Updates on {{title}}',
    'comment', 'comment.state=\'confirmed\'', 'created desc',
    'Update by {{name}}', '/?id={{problem_id}}#comment_{{id}}', '{{text}}', 'alert-update');

-- New problems anywhere on the site
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_problems', '', '',
    'New problems on FixMyStreet', '/', 'The latest problems reported by users',
    'problem', 'problem.state in (\'confirmed\', \'fixed\')', 'created desc',
    '{{title}}, {{confirmed}}', '/?id={{id}}', '{{detail}}', 'alert-problem');

-- New problems around a location
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('local_problems', '', '',
    'New local problems on FixMyStreet', '/', 'The latest local problems reported by users',
    'problem_find_nearby(?, ?, ?) as nearby,problem', 'nearby.problem_id = problem.id and problem.state in (\'confirmed\', \'fixed\')', 'created desc',
    '{{title}}, {{confirmed}}', '/?id={{id}}', '{{detail}}', 'alert-problem');

-- New problems sent to a particular council
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('council_problems', '', '',
    'New problems to {{COUNCIL}} on FixMyStreet', '/reports', 'The latest problems for {{COUNCIL}} reported by users',
    'problem', 'problem.state in (\'confirmed\', \'fixed\') and (council like \'%\'||?||\'%\'
        or council is null) and areas like \'%,\'||?||\',%\'', 'created desc',
    '{{title}}, {{confirmed}}', '/?id={{id}}', '{{detail}}', 'alert-problem'
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
    'problem', 'problem.state in (\'confirmed\', \'fixed\') and (council like \'%\'||?||\'%\'
        or council is null) and areas like \'%,\'||?||\',%\'', 'created desc',
    '{{title}}, {{confirmed}}', '/?id={{id}}', '{{detail}}', 'alert-problem'
);

-- New problems within a particular voting area (ward, constituency, whatever)
insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('area_problems', '', '',
    'New problems within {{NAME}}\'s boundary on FixMyStreet', '/reports',
    'The latest problems within {{NAME}}\'s boundary reported by users', 'problem',
    'problem.state in (\'confirmed\', \'fixed\') and areas like \'%,\'||?||\',%\'', 'created desc',
    '{{title}}, {{confirmed}}', '/?id={{id}}', '{{detail}}', 'alert-problem-area'
);

