use Test::MockModule;

use FixMyStreet::TestMech;
use Open311::PostServiceRequestUpdates;

use_ok 'FixMyStreet::Cobrand::Northamptonshire';

my $mech = FixMyStreet::TestMech->new;

use open ':std', ':encoding(UTF-8)'; 

my $ncc = $mech->create_body_ok(2234, 'Northamptonshire County Council', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j', send_comments => 1 });
my $nbc = $mech->create_body_ok(2397, 'Northampton Borough Council');

my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $ncc);
my $user = $mech->create_user_ok('user@example.com', name => 'User');

my $ncc_contact = $mech->create_contact_ok(
    body_id => $ncc->id,
    category => 'Trees',
    email => 'trees-2234@example.com',
);

my $nbc_contact = $mech->create_contact_ok(
    body_id => $nbc->id,
    category => 'Flytipping',
    email => 'flytipping-2397@example.com',
);

my ($report) = $mech->create_problems_for_body(1, $ncc->id, 'Defect Problem', {
    whensent => DateTime->now()->subtract( minutes => 5 ),
    external_id => 1,
    send_method_used => 'Open311',
    user => $counciluser
});

my $comment = FixMyStreet::DB->resultset('Comment')->create( {
    mark_fixed => 0,
    user => $user,
    problem => $report,
    anonymous => 0,
    text => 'this is a comment',
    confirmed => DateTime->now,
    state => 'confirmed',
    problem_state => 'confirmed',
    cobrand => 'default',
} );

$ncc->update( { comment_user_id => $counciluser->id } );


subtest 'Check district categories hidden on cobrand' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { northamptonshire => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok( '/around' );
        $mech->submit_form_ok( { with_fields => { pc => 'NN1 1NS' } },
            "submit location" );
        is_deeply $mech->page_errors, [], "no errors for pc";

        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->content_contains('Trees');
        $mech->content_lacks('Flytipping');
    };
};

subtest 'Check updates not sent for defects' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { northamptonshire => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 0, "comment sending not attempted";
    is $comment->get_extra_metadata('cobrand_skipped_sending'), 1, "skipped sending comment";
};

$report->update({ user => $user });
$comment->update({ extra => undef });
subtest 'check updates sent for non defects' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { northamptonshire => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 1, "comment sending attempted";
};

my $cobrand = FixMyStreet::Cobrand::Northamptonshire->new;

subtest 'check updates disallowed correctly' => sub {
    is $cobrand->updates_disallowed($report), 0;
    $report->update({ state => 'closed' });
    is $cobrand->updates_disallowed($report), 1;
    $report->update({ state => 'confirmed', user => $counciluser });
    is $cobrand->updates_disallowed($report), 1;
};

subtest 'check pin colour / reference shown' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'northamptonshire',
        #MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        is $cobrand->pin_colour($report, 'around'), 'blue';
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('ref:&nbsp;' . $report->id);
        $report->update({ user => $user });
        is $cobrand->pin_colour($report, 'around'), 'yellow';
        is $cobrand->pin_colour($report, 'my'), 'red';
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('ref:&nbsp;' . $report->id);
    };
};

done_testing();
