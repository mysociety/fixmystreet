use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::UpdateAllReports;
use FixMyStreet::Script::Alerts;
use t::Mock::Tilma;

my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => qr/tilma/);

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(2494, 'Thamesmead', { cobrand => 'thamesmead' }); # Using Bexley as area
my $contact = $mech->create_contact_ok(body_id => $body->id, category => 'Overgrown shrub beds', email => 'shrubs@example.org');
$mech->create_contact_ok(body_id => $body->id, category => 'Thamesmead graffiti', email => 'thamesmead@example.org');
my $bexley = $mech->create_body_ok(2494, 'London Borough of Bexley', {cobrand => 'bexley'});
$mech->create_contact_ok(body_id => $bexley->id, category => 'Bexley graffiti', email => 'bexley@example.org');

my $user1 = $mech->create_user_ok('user1@example.org', email_verified => 1, name => 'User 1');
my $user2 = $mech->create_user_ok('user2@example.org', email_verified => 1, name => 'User 2');
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $body, email_verified => 1, name => 'Staff 1');
my $superuser = $mech->create_user_ok('superuser@example.org', is_superuser => 1, email_verified => 1, name => 'SU 1');

my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2493,", category => 'Overgrown shrub beds', cobrand => 'thamesmead',
    user => $user1,});

my $osm = Test::MockModule->new('FixMyStreet::Geocode');

$osm->mock('cache', sub {
    [
        {
            'class' => 'highway',
            'boundingbox' => [
                               '52.4062908',
                               '52.4069021',
                               '-1.6015067',
                               '-1.5979428'
                             ],
            'type' => 'residential',
            'lon' => '-1.5995035',
            'display_name' => 'Glendale Way, Tanyard Farm, Eastern Green, Coventry, West Midlands Combined Authority, England, CV4 9XF, United Kingdom',
            'osm_type' => 'way',
            'osm_id' => 8317909,
            'importance' => '0.3',
            'lat' => '52.4064971',
            'place_id' => 99338892,
            'licence' => "Data \x{a9} OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright"
        },
        {
            'display_name' => 'Glendale Way, Tanyard Farm, Eastern Green, Coventry, West Midlands Combined Authority, England, CV4 9YQ, United Kingdom',
            'lon' => '-1.597785',
            'boundingbox' => [
                               '52.4070828',
                               '52.4071357',
                               '-1.597785',
                               '-1.5976885'
                             ],
            'type' => 'unclassified',
            'class' => 'highway',
            'lat' => '52.4070828',
            'licence' => "Data \x{a9} OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright",
            'place_id' => 97338253,
            'importance' => '0.3',
            'osm_type' => 'way',
            'osm_id' => 8438133
        },
        {
            'importance' => '0.3',
            'place_id' => 97802139,
            'lat' => '51.5055221',
            'licence' => "Data \x{a9} OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright",
            'osm_id' => 5181163,
            'osm_type' => 'way',
            'display_name' => 'Glendale Way, London, Thamesmead, Greater London, England, SE28 8HA, United Kingdom',
            'type' => 'residential',
            'boundingbox' => [
                               '51.5041544',
                               '51.5065265',
                               '0.1235885',
                               '0.1236829'
                             ],
            'lon' => '0.123597',
            'class' => 'highway'
        },
        {
            'importance' => '0.3',
            'place_id' => 97802139,
            'lat' => '51.5055221',
            'licence' => "Data \x{a9} OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright",
            'osm_id' => 5181163,
            'osm_type' => 'way',
            'display_name' => 'Glendale Way, London, London Borough of Bexley, Greater London, England, SE28 8HA, United Kingdom',
            'type' => 'residential',
            'boundingbox' => [
                               '51.5041544',
                               '51.5065265',
                               '0.1235885',
                               '0.1236829'
                             ],
            'lon' => '0.123597',
            'class' => 'highway'
        }
    ]
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'thamesmead' ],
    COBRAND_FEATURES => {
        updates_allowed => {
            thamesmead => 'reporter/staff',
        }
    }
}, sub {
    subtest 'Check updating a normal report' => sub {
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->submit_form_ok({ with_fields => {update => 'Still not fixed'} }, 'Reporter can update report');

        $mech->log_in_ok($user2->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('This report is now closed to updates', 'Other user can not update report');

        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->submit_form_ok({ with_fields => {update => 'Confirm this is still not fixed'} }, 'Staff user can update report');

        $mech->log_in_ok($superuser->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->submit_form_ok({ with_fields => {update => 'Re-confirm this is still not fixed'} }, 'Superuser can update report');
    };
    subtest 'Check updating a closed_updates report' => sub {
        $problem->set_extra_metadata('closed_updates' => 1);
        $problem->update;
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('This report is now closed to updates', 'Reporter can not update reports with closed updates');

        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('This report is now closed to updates', 'Staff user can not update reports with closed updates');

        $mech->log_in_ok($superuser->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('This report is now closed to updates', 'Superuser can not update reports with closed updates');
    };
    subtest 'Check updating an updates_disallowed report' => sub {
        $problem->set_extra_metadata('closed_updates' => undef);
        $problem->update;
        $contact->set_extra_metadata('updates_disallowed' => 1);
        $contact->update;

        $mech->log_in_ok($user1->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('This report is now closed to updates', 'Reporter can not update reports with updates disallowed');

        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('This report is now closed to updates', 'Staff user can not update reports with updates disallowed');

        $mech->log_in_ok($superuser->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('This report is now closed to updates', 'Superuser can not update reports with updates disallowed');
    };
    subtest 'Check updating a fixed report' => sub {
        $contact->set_extra_metadata('updates_disallowed' => undef);
        $contact->update;
        $problem->update({ state => 'fixed'});

        $mech->log_in_ok($user1->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('form_reopen', 'Reporter can check reopen box on closed report');

        $mech->log_in_ok($user2->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_lacks('form_reopen', 'Other user can not check reopen box on closed report');

        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('option value="confirmed"', 'Staff user can select "Open" on closed report');

        $mech->log_in_ok($superuser->email);
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('option value="confirmed"', 'Superuser can select "Open" on closed report');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'thamesmead' ],
}, sub {
    $mech->get_ok('/', "Get search page");
    $mech->submit_form_ok(
        { with_fields => {
            pc => 'Glendale Way'
        }
    }, "Search for Glendale Way");
    my @glendales = $mech->content =~ /Glendale Way,/g;
    ok (scalar @glendales == 2, "Finds only Glendale Ways with Bexley or Thamesmead in the address");
};

subtest "Thamesmead categories replace cobrand categories on FMS when on Thamesmead asset" => sub {

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bexley' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok("/report/new/ajax?latitude=51.466707&longitude=0.181108");
        $mech->content_contains('Bexley graffiti');
        $mech->content_lacks('Thamesmead graffiti');

        $mech->get_ok("/report/new/ajax?latitude=51.512868&longitude=0.125436");
        $mech->content_contains('Thamesmead graffiti');
        $mech->content_lacks('Bexley graffiti');
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok("/report/new/ajax?latitude=51.466707&longitude=0.181108");
        $mech->content_contains('Bexley graffiti');
        $mech->content_lacks('Thamesmead graffiti');

        $mech->get_ok("/report/new/ajax?latitude=51.512868&longitude=0.125436");
        $mech->content_contains('Thamesmead graffiti');
        $mech->content_lacks('Bexley graffiti');
    };
};

subtest "Thamesmead categories appear on Thamesmead asset, Bexley categories when not on asset in Bexley" => sub {

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'thamesmead' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok("/report/new/ajax?latitude=51.466707&longitude=0.181108");
        $mech->content_lacks('Thamesmead graffiti');
        $mech->content_contains('Bexley graffiti');

        $mech->get_ok("/report/new/ajax?latitude=51.512868&longitude=0.125436");
        $mech->content_contains('Thamesmead graffiti');
        $mech->content_lacks('Bexley graffiti');
    };
};

subtest 'Check Thamesmead not in summary stats' => sub {
    my $data = FixMyStreet::Script::UpdateAllReports::generate_dashboard();
    is_deeply $data->{top_five_bodies}, [];
    is_deeply $data->{top_five_categories}, [];
};

subtest "Bexley report confirmation links to report on FMS" => sub {

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'thamesmead' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
    $mech->log_out_ok;
    FixMyStreet::Script::Alerts::send_updates();
    $mech->clear_emails_ok;
    $mech->get_ok("/report/new?latitude=51.466707&longitude=0.181108");
    $mech->submit_form_ok({ with_fields => { category => 'Bexley graffiti' } });
    $mech->submit_form_ok({
        with_fields => {
            title => 'Bexley report',
            detail => 'Report not on Thamesmead',
        }
    });
    $mech->submit_form_ok({
        with_fields => {
        username_register => 'test@email.com',
        name => 'Test user',
        },
    }, "submit details");
    FixMyStreet::Script::Alerts::send_updates();
    my $email = $mech->get_email;
    my $link = $mech->get_link_from_email($email);
    $mech->get_ok($link);
    $mech->content_like(qr#.*?http://www.example.org.*?Bexley report#, 'Title link goes to FMS');
    $mech->content_like(qr#follow this problem on.*?http://www.example.org.*?FixMyStreet\.com#, 'FMS link goes to FMS');
    }
};

subtest "Thamesmead staff comments are ascribed to Peabody" => sub {
    FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'thamesmead' ],
    }, sub {

        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Title', {
        areas => "2493,", category => 'Overgrown shrub beds', cobrand => 'thamesmead',
        user => $user1});

        my $comment = FixMyStreet::DB->resultset('Comment')->find_or_create( {
            problem_state => 'fixed - council',
            problem_id => $problem->id,
            user_id    => $staff_user->id,
            name       => 'User',
            text       => "Test comment",
            state      => 'confirmed',
            confirmed  => 'now()',
        } );

        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains("Posted by <strong>Peabody</strong>");
    };
};

done_testing();
