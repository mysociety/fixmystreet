use FixMyStreet::Script::Reports;
use FixMyStreet::TestMech;
use t::Mock::Bexley;

my $mech = FixMyStreet::TestMech->new;

my $whitespace_mock = $bexley_mocks{whitespace};

my $user
    = $mech->create_user_ok( 'bob@example.org', name => 'Original Name' );

my $body = $mech->create_body_ok( 2494, 'Bexley', { cobrand => 'bexley' } );

my $contact = $mech->create_contact_ok(
    body     => $body,
    category => 'Sharps collection',
    group    => ['Waste'],
    email    => 'whitespace_sharps',
    extra    => { type => 'waste' }
);
$contact->set_extra_fields(
    { code => 'collection_date', required => 1, automated => 'hidden_field' },
);
$contact->update;

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'bexley',
    COBRAND_FEATURES => {
        waste => { bexley => 1 },
        waste_features => {
            bexley => {
                sharps_enabled => 1,
            },
        },
        whitespace => { bexley => { url => 'http://example.org/' } },
    },
}, sub {
    subtest 'Eligible property can make sharps booking' => sub {
        $mech->get_ok('/waste/10001');
        $mech->content_contains('Sharps');

        $mech->get_ok('/waste/10001/sharps');
        $mech->content_contains('Book sharps collection');
        $mech->content_contains('Before you start your booking');
        $mech->content_contains('TODO');
        $mech->submit_form_ok;

        $mech->content_contains('About you');
        $mech->submit_form_ok(
            {   with_fields => {
                    name  => 'Bob Marge',
                    email => $user->email,
                    phone => '44 07 111 111 111',
                }
            }
        );

        $mech->content_contains('Choose date for collection');
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2025-06-27;1;' } } );

        $mech->content_contains('Collection and delivery');
        $mech->submit_form_ok(
            {   with_fields => {
                    sharps_collecting => 'No',
                    sharps_delivering => 'No',
                }
            }
        );

        $mech->content_contains( 'You must select at least one',
            'Error if neither collection nor delivery selected' );
        $mech->submit_form_ok(
            {   with_fields => {
                    sharps_collecting => 'No',
                    sharps_delivering => 'Yes',
                }
            }
        );

        $mech->content_contains( 'Delivery details',
            'Goes to delivery details if collection not selected' );
        $mech->back;
        $mech->submit_form_ok(
            {   with_fields => {
                    sharps_collecting => 'Yes',
                    sharps_delivering => 'Yes',
                }
            }
        );

        $mech->content_contains('Collection quantities');
        $mech->submit_form_ok(
            {   with_fields => {
                    collect_small_quantity => 3,
                    collect_large_quantity => 2,
                }
            }
        );

        $mech->content_contains('Collection details');
        $mech->submit_form_ok(
            {   with_fields => {
                    collect_location => 'Doorstep',
                    collect_glucose_monitor => 'No',
                    collect_cytotoxic => 'Yes',
                }
            }
        );

        $mech->content_contains('Delivery details');
        $mech->submit_form_ok(
            {   with_fields => {
                    deliver_size => '1-litre',
                    deliver_quantity => 5,
                }
            }
        );

        $mech->content_contains('Booking Summary');
        $mech->content_contains('Friday 27 June 2025');
        $mech->submit_form_ok(
            {   with_fields => {
                    tandc => 1,
                }
            }
        );

        $mech->content_contains('Sharps booking confirmed');
        $mech->content_contains('Friday 27 June 2025');
        ok $mech->email_count_is(0), 'No email sent straightaway';

        # Check content of report in DB
        my $report = FixMyStreet::DB->resultset('Problem')->first;
        is $report->category, 'Sharps collection';
        is $report->cobrand_data, 'waste';
        like $report->detail, qr/Address:.*DA1 3NP/;
        is $report->non_public, 1;
        is $report->state, 'confirmed';
        is $report->title, 'Sharps collection';
        is $report->uprn, '10001';
        is $report->get_extra_field_value('collection_date'), '2025-06-27';

        # XXX Test sending to Whitespace
        # $mech->clear_emails_ok();
        # FixMyStreet::Script::Reports::send();
        # $mech->email_count_is(0);

        # $report->discard_changes;
        # is $report->external_id, 'TODO';
    };
};

done_testing;
