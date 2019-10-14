use FixMyStreet::TestMech;
use FixMyStreet::App;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2482, 'TfL');
my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
$staffuser->user_body_permissions->create({
    body => $body,
    permission_type => 'contribute_as_body',
});
$staffuser->user_body_permissions->create({
    body => $body,
    permission_type => 'default_to_body',
});


my $contact1 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Bus stops',
    email => 'busstops@example.com',
);
my $contact2 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Traffic lights',
    email => 'trafficlights@example.com',
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'tfl',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        anonymous_account => {
            tfl => 'anonymous'
        }
    }
}, sub {

subtest "test report creation anonymously by button" => sub {
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'BR1 3UH', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            button => 'submit_register',
            with_fields => {
                title => 'Test Report 1',
                detail => 'Test report details.',
                name => 'Joe Bloggs',
                may_show_name => '1',
                category => 'Bus stops',
            }
        },
        "submit good details"
    );

    is_deeply $mech->page_errors, [
        'Please enter your email'
    ], "check there were no errors";

    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'BR1 3UH', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            button => 'report_anonymously',
            with_fields => {
                title => 'Test Report 1',
                detail => 'Test report details.',
                category => 'Bus stops',
            }
        },
        "submit good details"
    );
    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 1'});
    ok $report, "Found the report";

    $mech->content_contains('Your issue is on its way to TfL');
    $mech->content_contains('Your reference for this report is FMS' . $report->id);

    is_deeply $mech->page_errors, [], "check there were no errors";

    is $report->state, 'confirmed', "report confirmed";
    $mech->get_ok( '/report/' . $report->id );

    is $report->bodies_str, $body->id;
    is $report->name, 'Anonymous user';
    like $report->user->email, qr/anonymous-[2-9a-km-zA-NP-Z]{18}\@tfl.gov.uk/;
    is $report->anonymous, 1; # Doesn't change behaviour here, but uses anon account's name always
    is $report->get_extra_metadata('contributed_as'), 'anonymous_user';

    my $alert = FixMyStreet::App->model('DB::Alert')->find( {
        user => $report->user,
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    is $alert, undef, "no alert created";

    $mech->not_logged_in_ok;
};

subtest "test report creation anonymously by staff user" => sub {
    $mech->log_in_ok( $staffuser->email );
    $mech->get_ok('/around');
    $mech->submit_form_ok( { with_fields => { pc => 'BR1 3UH', } }, "submit location" );
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->submit_form_ok(
        {
            button => 'report_anonymously',
            with_fields => {
                title => 'Test Report 2',
                detail => 'Test report details.',
                category => 'Bus stops',
            }
        },
        "submit good details"
    );
    is_deeply $mech->page_errors, [], "check there were no errors";

    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Test Report 2'});
    ok $report, "Found the report";

    $mech->content_contains('Your issue is on its way to TfL') or diag $mech->content;
    $mech->content_contains('Your reference for this report is FMS' . $report->id);

    is $report->state, 'confirmed', "report confirmed";
    $mech->get_ok( '/report/' . $report->id );

    is $report->bodies_str, $body->id;
    is $report->name, 'Anonymous user';
    like $report->user->email, qr/anonymous-[2-9a-km-zA-NP-Z]{18}\@tfl.gov.uk/;
    is $report->anonymous, 1;
    is $report->get_extra_metadata('contributed_as'), 'anonymous_user';

    my $alert = FixMyStreet::App->model('DB::Alert')->find( {
        user => $report->user,
        alert_type => 'new_updates',
        parameter => $report->id,
    } );
    is $alert, undef, "no alert created";

    $mech->log_out_ok;
};

subtest "reports have unique users" => sub {
    my ($report1, $report2) = FixMyStreet::DB->resultset("Problem")->all;

    isnt $report1->user->id, $report2->user->id, 'reports have different users';
    isnt $report1->user->email, $report2->user->email, 'anonymous users have different email addresses';
};

subtest 'check lookup by reference' => sub {
    my $id = FixMyStreet::DB->resultset("Problem")->first->id;

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => 'FMS12345' } }, 'bad ref');
    $mech->content_contains('Searching found no reports');

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "FMS$id" } }, 'good FMS-prefixed ref');
    is $mech->uri->path, "/report/$id", "redirected to report page when using FMS-prefixed ref";

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "FMS $id" } }, 'good FMS-prefixed with a space ref');
    is $mech->uri->path, "/report/$id", "redirected to report page when using FMS-prefixed ref";

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => "$id" } }, 'good ref');
    is $mech->uri->path, "/report/$id", "redirected to report page when using non-prefixed ref";
};


};

done_testing();
