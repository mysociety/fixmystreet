use FixMyStreet::TestMech;

use_ok 'FixMyStreet::Script::UK::AutoClose';

my $mech = FixMyStreet::TestMech->new;
my $comment_user = $mech->create_user_ok('comment@example.com');
my $body = $mech->create_body_ok(
    2495,
    'Enfield Council',
    {   send_method  => 'Open311',
        cobrand      => 'enfield',
        api_key      => 'key',
        endpoint     => 'endpoint',
        jurisdiction => 'j',
        comment_user => $comment_user,
    }
);
$mech->create_contact_ok( body => $body, category => 'Other', email => 'OTHER' );
my $template = $body->add_to_response_templates(
    {   title         => 'Autoclose old',
        text          => 'Autoclosed',
        state         => 'closed',
        auto_response => 1
    }
);

my ($older_problem_default) = $mech->create_problems_for_body(
    1, $body,
    'Older Default',
    { dt => DateTime->today()->subtract( days => 2 ) },
);
my ($older_problem_action_scheduled) = $mech->create_problems_for_body(
    1, $body,
    'Older Action Scheduled',
    {   dt    => DateTime->today()->subtract( days => 2 ),
        state => 'action_scheduled',
    },
);
my ($older_problem_investigating) = $mech->create_problems_for_body(
    1, $body,
    'Older Investigating',
    {   dt    => DateTime->today()->subtract( days => 2 ),
        state => 'investigating',
    },
);
my ($newer_problem_action_scheduled) = $mech->create_problems_for_body(
    1, $body,
    'Newer Action Scheduled',
    { state => 'action_scheduled' },
);

my $ac = FixMyStreet::Script::UK::AutoClose->new(
    commit => 1,
    retain_alerts => 1,
    body_name => 'Enfield Council',
    states => [ 'action_scheduled', 'investigating' ],
    to => 1,
);

$ac->close;

$older_problem_default->discard_changes;
is $older_problem_default->state, 'confirmed', 'Default older problem unchanged';

$older_problem_action_scheduled->discard_changes;
is $older_problem_action_scheduled->state, 'closed', 'Older action_scheduled problem closed';

$older_problem_investigating->discard_changes;
is $older_problem_investigating->state, 'closed', 'Older investigating problem closed';

$newer_problem_action_scheduled->discard_changes;
is $newer_problem_action_scheduled->state, 'action_scheduled', 'Newer action_scheduled problem unchanged';

done_testing;
