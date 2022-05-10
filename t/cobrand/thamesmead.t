use Test::MockModule;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(2493, 'Thamesmead'); # Using Greenwich as area
my $contact = $mech->create_contact_ok(body_id => $body->id, category => 'Overgrown shrub beds', email => 'shrubs@example.org');

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
}, sub {
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

done_testing();
