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

my ($older_problem_default) = $mech->create_problems_for_body(
    1, $body,
    'Older Default',
    { dt => DateTime->today()->subtract( days => 28 ) },
);
my ($older_problem_SL12) = $mech->create_problems_for_body(
    1, $body,
    'Older SL12',
    {
        dt => DateTime->today()->subtract( days => 28 ),
        extra => { external_status_code => 'SL12' },
    },
);

my ($newer_problem_default) = $mech->create_problems_for_body(
    1, $body,
    'Newer Default',
    { dt => DateTime->today()->subtract( days => 27 ) },
);
my ($newer_problem_SL12) = $mech->create_problems_for_body(
    1, $body,
    'Newer SL12',
    {
        dt => DateTime->today()->subtract( days => 27 ),
        extra => { external_status_code => 'SL12' },
    },
);

my $ac = FixMyStreet::Script::UK::AutoClose->new(
    commit => 1,
    retain_alerts => 1,
    body_name => 'Central Bedfordshire Council',
    to => 28,
    closure_text => 'AUTOCLOSED',
    extra => { external_status_code => 'SL12' },
);

$ac->close;

$older_problem_default->discard_changes;
is $older_problem_default->state, 'confirmed', 'Default older problem unchanged';
is $older_problem_default->comments, 0, 'no comments';

$older_problem_SL12->discard_changes;
is $older_problem_SL12->state, 'closed', 'Older SL12 problem closed';
is $older_problem_SL12->comments->first->text, 'AUTOCLOSED', 'comment set';

$newer_problem_default->discard_changes;
is $newer_problem_default->state, 'confirmed', 'Default newer problem unchanged';
is $newer_problem_default->comments, 0, 'no comments';

$newer_problem_SL12->discard_changes;
is $newer_problem_SL12->state, 'confirmed', 'Newer SL12 problem unchanged';
is $newer_problem_SL12->comments, 0, 'no comments';

done_testing;
