use utf8;
use CGI::Simple;
use DateTime;
use Test::MockModule;
use FixMyStreet::TestMech;
use Open311;
use Open311::GetServiceRequests;
use Open311::GetServiceRequestUpdates;
use Open311::PostServiceRequestUpdates;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $params = {
    send_method => 'Open311',
    send_comments => 1,
    api_key => 'KEY',
    endpoint => 'endpoint',
    jurisdiction => 'home',
    can_be_devolved => 1,
};

my $hackney = $mech->create_body_ok(2508, 'Hackney Council', $params);
my $contact = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Potholes',
    email => 'pothole@example.org',
);
$contact->set_extra_fields( ( {
    code => 'urgent',
    datatype => 'string',
    description => 'question',
    variable => 'true',
    required => 'false',
    order => 1,
    datatype_description => 'datatype',
} ) );
$contact->update;

my $user = $mech->create_user_ok('user@example.org', name => 'Test User');
my $hackney_user = $mech->create_user_ok('iow_user@example.org', name => 'Hackney User', from_body => $hackney);
$hackney_user->user_body_permissions->create({
    body => $hackney,
    permission_type => 'moderate',
});

my $contact2 = $mech->create_contact_ok(
    body_id => $hackney->id,
    category => 'Roads',
    email => 'roads@example.org',
    send_method => 'Triage',
);

my $admin_user = $mech->create_user_ok('admin-user@example.org', name => 'Admin User', from_body => $hackney);

$admin_user->user_body_permissions->create({
    body => $hackney,
    permission_type => 'triage'
});

my @reports = $mech->create_problems_for_body(1, $hackney->id, 'A Hackney report', {
    confirmed => '2019-10-25 09:00',
    lastupdate => '2019-10-25 09:00',
    latitude => 51.552267,
    longitude => -0.063316,
    user => $user,
    external_id => 101202303
});

subtest "check clicking all reports link" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney'],
    }, sub {
        $mech->get_ok('/');
        $mech->follow_link_ok({ text => 'All reports' });
    };

    $mech->content_contains("A Hackney report", "Hackney report there");
    $mech->content_contains("Hackney Council", "is still on cobrand");
};

subtest "check moderation label uses correct name" => sub {
    my $REPORT_URL = '/report/' . $reports[0]->id;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney'],
    }, sub {
        $mech->log_out_ok;
        $mech->log_in_ok( $hackney_user->email );
        $mech->get_ok($REPORT_URL);
        $mech->content_lacks('show-moderation');
        $mech->follow_link_ok({ text_regex => qr/^Moderate$/ });
        $mech->content_contains('show-moderation');
        $mech->submit_form_ok({ with_fields => {
            problem_title  => 'Good good',
            problem_detail => 'Good good improved',
        }});
        $mech->base_like( qr{\Q$REPORT_URL\E} );
        $mech->content_like(qr/Moderated by Hackney Council/);
    };
};

$_->delete for @reports;

my $system_user = $mech->create_user_ok('system_user@example.org');

my ($p) = $mech->create_problems_for_body(1, $hackney->id, '', { cobrand => 'hackney' });
my $alert = FixMyStreet::DB->resultset('Alert')->create( {
    parameter  => $p->id,
    alert_type => 'new_updates',
    user       => $user,
    cobrand    => 'hackney',
} )->confirm;

subtest "sends branded alert emails" => sub {
    $mech->create_comment_for_problem($p, $system_user, 'Other User', 'This is some update text', 'f', 'confirmed', undef);
    $mech->clear_emails_ok;

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney','fixmystreet'],
    }, sub {
        FixMyStreet::Script::Alerts::send();
    };

    $mech->email_count_is(1);
    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email), qr/Hackney Council/, "emails are branded";
};

$p->comments->delete;
$p->delete;

subtest "sends branded confirmation emails" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'hackney' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'E8 1DY', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    username      => 'test-1@example.com',
                    category      => 'Roads',
                }
            },
            "submit good details"
        );

        $mech->email_count_is(1);
        my $email = $mech->get_email;
        ok $email, "got an email";
        like $mech->get_text_body_from_email($email), qr/Hackney Council/, "emails are branded";

        my $url = $mech->get_link_from_email($email);
        $mech->get_ok($url);
        $mech->clear_emails_ok;
    };
};

#subtest "sends branded report sent emails" => sub {
    #$mech->clear_emails_ok;
    #FixMyStreet::override_config {
        #STAGING_FLAGS => { send_reports => 1 },
        #MAPIT_URL => 'http://mapit.uk/',
        #ALLOWED_COBRANDS => ['hackney','fixmystreet'],
    #}, sub {
        #FixMyStreet::Script::Reports::send();
    #};
    #$mech->email_count_is(1);
    #my $email = $mech->get_email;
    #ok $email, "got an email";
    #like $mech->get_text_body_from_email($email), qr/Hackney Council/, "emails are branded";
#};

subtest "check category extra uses correct name" => sub {
    my @extras = ( {
            code => 'test',
            datatype => 'string',
            description => 'question',
            variable => 'true',
            required => 'false',
            order => 1,
            datatype_description => 'datatype',
        } );
    $contact2->set_extra_fields( @extras );
    $contact2->update;

    my $extra_details;

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['hackney','fixmystreet'],
    }, sub {
        $extra_details = $mech->get_ok_json('/report/new/category_extras?category=Roads&latitude=51.552267&longitude=-0.063316');
    };

    like $extra_details->{category_extra}, qr/Hackney Council/, 'correct name in category extras';
};


done_testing();
