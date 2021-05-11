use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
my $mech = FixMyStreet::TestMech->new;

# Create test data
my $user = $mech->create_user_ok( 'rutland@example.com' );
my $body = $mech->create_body_ok( 2482, 'Rutland County Council');
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Other',
    email => 'LIGHT',
);
$contact->set_extra_metadata(
    group => 'Street Furniture',
    group_hint => '<span>This is for things like lights and bins</span>',
    category_hint => '<span>For problems with street lighting</span>',
);
$contact->update;

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'rutland',
    user => $user,
});
my $report = $reports[0];

for my $update ('in progress', 'unable to fix') {
    FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => $update,
        problem_id => $report->id,
        user_id    => $user->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "This update marks it as $update",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
}

subtest 'testing special Open311 behaviour', sub {
    $report->set_extra_fields();
    $report->update;
    $body->update( { send_method => 'Open311', endpoint => 'http://rutland.endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1 } );
    my $test_data;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet', 'rutland' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $test_data = FixMyStreet::Script::Reports::send();
    };
    $report->discard_changes;
    ok $report->whensent, 'Report marked as sent';
    is $report->send_method_used, 'Open311', 'Report sent via Open311';
    is $report->external_id, 248, 'Report has right external ID';

    my $req = $test_data->{test_req_used};
    my $c = CGI::Simple->new($req->content);
    is $c->param('attribute[title]'), $report->title, 'Request had title';
    is $c->param('attribute[description]'), $report->detail, 'Request had description';
    is $c->param('attribute[external_id]'), $report->id, 'Request had correct ID';
    is $c->param('jurisdiction_id'), 'FMS', 'Request had correct jurisdiction';
};

subtest "shows category and group hints when creating a new report", sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'rutland' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'LE15 0GJ', } },
            "submit location" );
        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );
        $mech->content_contains('This is for things like lights and bins') or diag $mech->content;
        $mech->content_contains('For problems with street lighting') or diag $mech->content;
    };
};

done_testing();
