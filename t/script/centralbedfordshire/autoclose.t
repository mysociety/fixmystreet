use FixMyStreet::TestMech;

use_ok 'FixMyStreet::Script::UK::AutoClose';

my $mech = FixMyStreet::TestMech->new;
my $comment_user = $mech->create_user_ok('comment@example.com');
my $body = $mech->create_body_ok(
    21070,
    'Central Bedfordshire Council',
    {   send_method  => 'Open311',
        cobrand      => 'centralbedfordshire',
        api_key      => 'key',
        endpoint     => 'endpoint',
        jurisdiction => 'j',
        comment_user => $comment_user,
    }
);
$mech->create_contact_ok( body => $body, category => 'Other', email => 'OTHER' );

my ($problem_no_updates) = $mech->create_problems_for_body(
    1, $body,
    'No Updates',
    { dt => DateTime->today()->subtract( days => 28 ) },
);

my ($problem_action_scheduled) = $mech->create_problems_for_body(
    1, $body,
    'Action Scheduled',
    {   dt    => DateTime->today()->subtract( days => 29 ),
        state => 'action_scheduled',
    },
);
FixMyStreet::DB->resultset('Comment')->new(
    {   problem       => $problem_action_scheduled,
        problem_state => 'action_scheduled',
        confirmed     => DateTime->today()->subtract( days => 28 ),
        _comment_defaults(),
    }
)->insert;

my ($problem_planned_recently) = $mech->create_problems_for_body(
    1, $body,
    'Planned Recently',
    {   dt    => DateTime->today()->subtract( days => 29 ),
        state => 'planned',
        extra => { external_status_code => 'SL12' },
    },
);
FixMyStreet::DB->resultset('Comment')->new(
    {   problem       => $problem_planned_recently,
        problem_state => 'planned',
        confirmed     => DateTime->today()->subtract( days => 27 ),
        _comment_defaults(),
    }
)->insert;

my ($problem_planned_while_ago_SL12) = $mech->create_problems_for_body(
    1, $body,
    'Planned While Ago SL12',
    {   dt    => DateTime->today()->subtract( days => 29 ),
        state => 'planned',
        extra => { external_status_code => 'SL12' },
    },
);
FixMyStreet::DB->resultset('Comment')->new(
    {   problem       => $problem_planned_while_ago_SL12,
        problem_state => 'planned',
        confirmed     => DateTime->today()->subtract( days => 28 ),
        _comment_defaults(),
    }
)->insert;

my ($problem_planned_while_ago_not_SL12) = $mech->create_problems_for_body(
    1, $body,
    'Planned While Ago Not SL12',
    {   dt    => DateTime->today()->subtract( days => 29 ),
        state => 'planned',
        extra => { external_status_code => 'SL13' },
    },
);
FixMyStreet::DB->resultset('Comment')->new(
    {   problem       => $problem_planned_while_ago_not_SL12,
        problem_state => 'planned',
        confirmed     => DateTime->today()->subtract( days => 28 ),
        _comment_defaults(),
    }
)->insert;

my ($problem_planned_closed_planned) = $mech->create_problems_for_body(
    1, $body,
    'Planned Closed Planned',
    {   dt    => DateTime->today()->subtract( days => 29 ),
        state => 'planned',
        extra => { external_status_code => 'SL12' },
    },
);
FixMyStreet::DB->resultset('Comment')->new(
    {   problem       => $problem_planned_closed_planned,
        problem_state => 'planned',
        confirmed     => DateTime->today()->subtract( days => 28 ),
        _comment_defaults(),
    }
)->insert;
FixMyStreet::DB->resultset('Comment')->new(
    {   problem       => $problem_planned_closed_planned,
        problem_state => 'closed',
        confirmed     => DateTime->today()->subtract( days => 27 ),
        _comment_defaults(),
    }
)->insert;
FixMyStreet::DB->resultset('Comment')->new(
    {   problem       => $problem_planned_closed_planned,
        problem_state => 'planned',
        confirmed     => DateTime->today()->subtract( days => 26 ),
        _comment_defaults(),
    }
)->insert;

my $ac = FixMyStreet::Script::UK::AutoClose->new(
    commit => 1,
    retain_alerts => 1,
    body_name => 'Central Bedfordshire Council',
    to => 28,
    closure_text => '',
    states => ['planned'],
    extra => { external_status_code => 'SL12' },
);

$ac->close;

$problem_no_updates->discard_changes;
is $problem_no_updates->state, 'confirmed', 'Problem with no updates is unchanged';
is $problem_no_updates->comments, 0, 'no comments';

$problem_action_scheduled->discard_changes;
is $problem_action_scheduled->state, 'action_scheduled', 'Problem with action scheduled is unchanged';
is $problem_action_scheduled->comments, 1, 'no new comments';

$problem_planned_recently->discard_changes;
is $problem_planned_recently->state, 'planned', 'Problem planned recently is unchanged';
is $problem_planned_recently->comments, 1, 'no new comments';

$problem_planned_while_ago_SL12->discard_changes;
is $problem_planned_while_ago_SL12->state, 'closed', 'Problem planned while ago (SL12) is closed';
my $last_comment = $problem_planned_while_ago_SL12->comments->order_by('-id')->first;
is $last_comment->problem_state, 'closed';
is $last_comment->text, '';

$problem_planned_while_ago_not_SL12->discard_changes;
is $problem_planned_while_ago_not_SL12->state, 'planned', 'Problem planned while ago (not SL12) is unchanged';
is $problem_planned_while_ago_not_SL12->comments, 1, 'no new comments';

$problem_planned_closed_planned->discard_changes;
is $problem_planned_closed_planned->state, 'planned', 'Problem planned/closed/planned is unchanged';
is $problem_planned_closed_planned->comments, 3, 'no new comments';

sub _comment_defaults {
    (   state   => 'confirmed',
        cobrand => 'centralbedfordshire',
        user    => $comment_user,
        text    => '',
    );
}

done_testing;
