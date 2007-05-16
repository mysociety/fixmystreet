insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_updates', 'select * from problem where id=?', 'problem',
    'Updates on {{title}}', '/', 'Updates on {{title}}',
    'comment', 'comment.state=\'confirmed\'', 'created desc',
    'Update by {{name}}', '/?id={{problem_id}}#comment_{{id}}', '{{text}}', 'alert-update');

insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('new_problems', '', '',
    'New problems on Neighbourhood Fix-It', '/', 'The latest problems reported by users',
    'problem', 'problem.state in (\'confirmed\', \'fixed\')', 'created desc',
    '{{title}}', '/?id={{id}}', '{{detail}}', 'alert-problem');

insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('local_problems', '', '',
    'New local problems on Neighbourhood Fix-It', '/', 'The latest local problems reported by users',
    'problem_find_nearby(?, ?, ?) as nearby,problem', 'nearby.problem_id = problem.id and problem.state in (\'confirmed\', \'fixed\')', 'created desc',
    '{{title}}', '/?id={{id}}', '{{detail}}', 'alert-problem');

insert into alert_type
(ref, head_sql_query, head_table,
    head_title, head_link, head_description,
    item_table, item_where, item_order,
    item_title, item_link, item_description, template)
values ('council_problems', '', '',
    'New local problems on Neighbourhood Fix-It', '/report', 'The latest local problems reported by users',
    'problem', 'problem.state in (\'confirmed\', \'fixed\') and council like \'%\'||?||\'%\'', 'created desc',
    '{{title}}', '/?id={{id}}', '{{detail}}', 'alert-problem'
);

