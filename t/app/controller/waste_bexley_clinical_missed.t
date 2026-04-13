use FixMyStreet::Script::Reports;
use FixMyStreet::TestMech;
use t::Mock::Bexley;

my $mech = FixMyStreet::TestMech->new;

my $whitespace_mock = $bexley_mocks{whitespace};

my $body = $mech->create_body_ok( 2494, 'Bexley', { cobrand => 'bexley' } );

my $user
    = $mech->create_user_ok( 'bob@example.org', name => 'Original Name' );
my $staff_user = $mech->create_user_ok(
    'staff@example.org',
    name      => 'Staff User',
    from_body => $body,
);

my $contact = $mech->create_contact_ok(
    body => $body,
    category => 'Report missed collection',
    email => 'missed@example.org',
    extra => { type => 'waste' },
    group => ['Waste'],
);
$contact->set_extra_fields(
    {
        code => "fixmystreet_id",
        required => "true",
        automated => "server_set",
        description => "external system ID",
    },
    {
        code => "service_item_name",
        required => "false",
        automated => "hidden_field",
        description => "Service item name",
    },
    {
        code => "assisted_yn",
        required => "false",
        automated => "hidden_field",
        description => "Assisted collection (Yes/No)",
    },
    {
        code => "location_of_containers",
        required => "false",
        automated => "hidden_field",
        description => "Location of containers",
    }
);
$contact->update;

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'bexley',
    COBRAND_FEATURES => {
        waste => { bexley => 1 },
        waste_features => {
            bexley => {
                clinical_enabled => 1,
            },
        },
        whitespace => { bexley => { url => 'http://example.org/' } },
    },
}, sub {
    subtest 'Property with clinical waste' => sub {
        $mech->get_ok('/waste/10001');

        $mech->text_contains(
            'Report an issue with my clinical waste collection',
            'Report issue link is still available',
        );

        $mech->text_lacks(
            'This property is set up for clinical waste',
            'Staff message not visible',
        );

        $mech->follow_link_ok(
            { text_regex => qr/issue with my clinical waste/ } );

        $mech->submit_form_ok(
            { with_fields => { registered => 'No' } }
        );

        $mech->content_contains(
            'complete the application form',
            'Selecting "No" shows message',
        );

        $mech->back;
        $mech->submit_form_ok(
            { with_fields => { registered => 'Yes' } }
        );
        $mech->submit_form_ok(
            { with_fields => { issue => 'Other' } }
        );

        $mech->text_contains(
            'Contact customer services',
            'Message to contact customer services',
        );

        $mech->back;
        $mech->submit_form_ok(
            { with_fields => { issue => 'Missed collection' } }
        );
        $mech->submit_form_ok(
            {   with_fields => {
                    name  => 'Trevor Trouble',
                    email => 'trevor@trouble.com',
                }
            }
        );

        $mech->text_contains(
            'Submit missed clinical collection',
            'On summary page',
        );

        $mech->submit_form_ok(
            { with_fields => { submit => 'Report collection as missed' } }
        );

        $mech->text_contains(
            'Thank you for reporting a missed collection',
            'Missed collection submitted',
        );

        my $report = FixMyStreet::DB->resultset('Problem')->first;

        is $report->category, 'Report missed collection';
        is $report->title, 'Clinical Waste';
        is $report->get_extra_field_value('service_item_name'), 'CW-SACK';
        is $report->get_extra_field_value('assisted_yn'), 'Yes';
        is $report->get_extra_field_value('location_of_containers'), '';
    };

    subtest 'Property without clinical waste' => sub {
        $mech->get_ok('/waste/10003');

        $mech->text_contains(
            'Report an issue with my clinical waste collection',
            'Report issue link is still available',
        );

        $mech->text_lacks(
            'This property is not set up for clinical waste',
            'Staff message not visible',
        );

        $mech->follow_link_ok(
            { text_regex => qr/issue with my clinical waste/ } );

        $mech->submit_form_ok(
            { with_fields => { registered => 'Yes' } }
        );

        $mech->text_contains(
            'we have not been able to confirm that you have scheduled clinical waste collections',
            'No clinical waste found',
        );
    };

    subtest 'Logged in as staff' => sub {
        $mech->log_in_ok( $staff_user->email );

        $mech->get_ok('/waste/10001');

        $mech->text_contains(
            'This property is set up for clinical waste',
            'Staff message visible',
        );

        $mech->get_ok('/waste/10003');
        $mech->text_contains(
            'This property is not set up for clinical waste',
            'Staff message visible',
        );
    };
};

done_testing;
