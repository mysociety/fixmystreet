use FixMyStreet::TestMech;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2237, 'Oxfordshire County Council');
$mech->create_contact_ok( body_id => $body->id, category => 'Potholes', email => 'potholes@example.com' );

my $staffuser = $mech->create_user_ok('body-user@example.net', name => 'Body User', from_body => $body->id);
$staffuser->user_body_permissions->create({ body => $body, permission_type => 'contribute_as_another_user' });
$staffuser->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');
my $user2 = $mech->create_user_ok('test2@example.com', name => 'Other User');

my ($report) = $mech->create_problems_for_body(1, $body->id, "Example", {
    user => $user,
    non_public => 1,
});
my $report_id = $report->id;

subtest "check cannot view non_public report by default" => sub {
    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->res->code, 403, "access denied";
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
    $mech->content_contains('permission to do that. If you are the problem reporter');
    $mech->content_lacks('Report another problem here');
    $mech->content_lacks($report->latitude);
    $mech->content_lacks($report->longitude);
};

subtest "check owner of report can view non public reports" => sub {
    $mech->log_in_ok( $report->user->email );
    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->res->code, 200, "report can be viewed";
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
    $mech->log_out_ok;

    $mech->log_in_ok( $user2->email );
    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->res->code, 403, "access denied to user who is not report creator";
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
    $mech->content_contains('permission to do that. If you are the problem reporter');
    $mech->content_lacks('Report another problem here');
    $mech->content_lacks($report->latitude);
    $mech->content_lacks($report->longitude);
    $mech->log_out_ok;
};

subtest "Logged email working on private report" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_in_ok($staffuser->email);
        $mech->get_ok('/report/new?latitude=51.7549262252&longitude=-1.25617899435');
        $mech->submit_form_ok({
            with_fields => {
                form_as => 'another_user',
                title => "Test Report",
                detail => 'Test report details.',
                category => 'Potholes',
                name => 'Another User',
                username => 'another@example.net',
                non_public => 1,
            }
        }, "submit details");
    };
    $mech->content_contains('Thank you for reporting this issue');
    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->state, 'confirmed', "report is now confirmed";
    is $report->non_public, 1;

    my $email = $mech->get_email;
    my $body = $mech->get_text_body_from_email($email);
    my $url = $mech->get_link_from_email($email);
    like $body, qr/Your report to Oxfordshire County Council has been logged/;
    $mech->get_ok($url);
    $mech->content_lacks('Get updates');
    $mech->content_contains('To provide an update, please');
};

done_testing();
