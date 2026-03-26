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
$mech->create_contact_ok( body => $body, category => 'Fly Tipping', email => 'jadu-flytipping' );
$mech->create_contact_ok( body => $body, category => 'Other', email => 'other' );

my ($flytipping_unsent) = $mech->create_problems_for_body(
    1, $body,
    'Fly Tipping Unsent',
    {   category => 'Fly Tipping',
        dt       => DateTime->today()->subtract( seconds => 1 ),
    },
);
my ($flytipping_sent_old) = $mech->create_problems_for_body(
    1, $body,
    'Fly Tipping Sent Old',
    {   category   => 'Fly Tipping',
        dt         => DateTime->today()->subtract( years => 1 ),
        send_state => 'sent',
    },
);
my ($flytipping_sent_new) = $mech->create_problems_for_body(
    1, $body,
    'Fly Tipping Sent New',
    {   category   => 'Fly Tipping',
        dt         => DateTime->today()->subtract( seconds => 1 ),
        send_state => 'sent'
    },
);
my ($flytipping_sent_in_progress) = $mech->create_problems_for_body(
    1, $body,
    'Fly Tipping Sent In Progress',
    {   category   => 'Fly Tipping',
        dt         => DateTime->today()->subtract( seconds => 1 ),
        state      => 'in_progress',
        send_state => 'sent',
    },
);
my ($other_unsent) = $mech->create_problems_for_body(
    1, $body,
    'Other Unsent',
    { dt => DateTime->today()->subtract( seconds => 1 ) },
);
my ($other_sent) = $mech->create_problems_for_body(
    1, $body,
    'Other Sent',
    {   dt         => DateTime->today()->subtract( seconds => 1 ),
        send_state => 'sent',
    },
);

my $ac = FixMyStreet::Script::UK::AutoClose->new(
    commit => 1,
    retain_alerts => 1,
    body_name => 'Central Bedfordshire Council',
    states => ['confirmed'],
    send_states => ['sent'],
    category => 'Fly Tipping',
    to => 0,
    closure_text => 'AUTOCLOSED',
);

$ac->close;

$flytipping_unsent->discard_changes;
is $flytipping_unsent->state, 'confirmed', 'Unsent flytipping: state unchanged';
is $flytipping_unsent->comments, 0, 'no comments';

$flytipping_sent_old->discard_changes;
is $flytipping_sent_old->state, 'closed', 'Old sent flytipping: closed';
is $flytipping_sent_old->comments->first->text, 'AUTOCLOSED', 'comment set';

$flytipping_sent_new->discard_changes;
is $flytipping_sent_new->state, 'closed', 'New sent flytipping: closed';
is $flytipping_sent_new->comments->first->text, 'AUTOCLOSED', 'comment set';

$flytipping_sent_in_progress->discard_changes;
is $flytipping_sent_in_progress->state, 'in_progress', 'In-progress flytipping: state unchanged';
is $flytipping_sent_in_progress->comments, 0, 'no comments';

$other_unsent->discard_changes;
is $other_unsent->state, 'confirmed', 'Unsent other: state unchanged';
is $other_unsent->comments, 0, 'no comments';

$other_sent->discard_changes;
is $other_sent->state, 'confirmed', 'Sent other: state unchanged';
is $other_sent->comments, 0, 'no comments';

done_testing;
