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
    email    => 'sharps@test.com',
    extra    => { type => 'waste' },
);
$contact->set_extra_fields(
    { code => 'collection_date', required => 1, automated => 'hidden_field' },
    { code => 'round_instance_id', required => 1, automated => 'hidden_field' },
    { code => 'collect_location', required => 1, automated => 'hidden_field' },
    { code => 'collect_location_other', required => 1, automated => 'hidden_field' },

    { code => 'sharps_collecting', required => 1, automated => 'hidden_field' },
    { code => 'sharps_collect_small_quantity', required => 1, automated => 'hidden_field' },
    { code => 'sharps_collect_large_quantity', required => 1, automated => 'hidden_field' },
    { code => 'sharps_deliver_glucose_monitor', required => 1, automated => 'hidden_field' },

    { code => 'sharps_delivering', required => 1, automated => 'hidden_field' },
    { code => 'sharps_deliver_size', required => 1, automated => 'hidden_field' },
    { code => 'sharps_deliver_quantity', required => 1, automated => 'hidden_field' },
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
        $mech->content_contains('Arrange a sharps collection');
        # Sharps section
        $mech->content_contains('You need to sign in to see the full details of this property.');
        $mech->content_contains('Book a collection');
        $mech->content_lacks('View existing collections');
        $mech->content_lacks('Check booking details');

        $mech->get_ok('/waste/10001/sharps');
        $mech->content_contains('Request a sharps box delivery or collection');
        $mech->content_contains('Before you make a request');
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

        # Validate individual and total collection limits
        $mech->submit_form_ok(
            { with_fields => { collect_small_quantity => 6, collect_large_quantity => 0 } } );
        $mech->content_contains('A maximum of 5 one-litre boxes can be collected per booking');
        $mech->submit_form_ok(
            { with_fields => { collect_small_quantity => 0, collect_large_quantity => 4 } } );
        $mech->content_contains('A maximum of 3 five-litre boxes can be collected per booking');
        $mech->submit_form_ok(
            { with_fields => { collect_small_quantity => 5, collect_large_quantity => 4 } } );
        $mech->content_contains('A maximum of 8 boxes can be collected per booking');

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
                    collect_location => 'On the doorstep',
                }
            }
        );

        $mech->content_contains('Delivery details');

        $mech->submit_form_ok(
            {   with_fields => {
                    deliver_glucose_monitor => 'Yes',
                }
            }
        );

        $mech->content_contains('you can only request 5-litre boxes');
        $mech->content_like(qr/value="1-litre"\s*disabled/s);
        $mech->content_like(qr/value="5-litre"\s*checked/s);

        $mech->back;

        $mech->submit_form_ok(
            {   with_fields => {
                    deliver_glucose_monitor => 'No',
                }
            }
        );

        $mech->content_lacks('you can only request 5-litre boxes');
        $mech->content_unlike(qr/value="1-litre"\s*disabled/s);
        $mech->content_unlike(qr/value="5-litre"\s*checked/s);

        # Validate delivery limits
        $mech->submit_form_ok(
            { with_fields => { deliver_size => '5-litre', deliver_quantity => 4 } } );
        $mech->content_contains('A maximum of 3 five-litre boxes can be delivered per booking');
        $mech->submit_form_ok(
            { with_fields => { deliver_size => '1-litre', deliver_quantity => 6 } } );
        $mech->content_contains('A maximum of 5 one-litre boxes can be delivered per booking');

        $mech->submit_form_ok(
            {   with_fields => {
                    deliver_size => '1-litre',
                    deliver_quantity => 5,
                }
            }
        );

        $mech->content_contains('Booking Summary');
        $mech->content_contains('Friday 27 June 2025');

        # Summary page should show sharps-specific details
        $mech->content_contains('Collection details');
        $mech->content_contains('Number of 1-litre boxes');
        $mech->content_contains('Number of 5-litre boxes');
        $mech->content_contains('Collection location');
        $mech->content_contains('On the doorstep');
        $mech->content_contains('Glucose monitoring devices');
        $mech->content_contains('Delivery details');
        $mech->content_contains('Box size');
        $mech->content_contains('1-litre');
        $mech->content_contains('Quantity');

        # Summary should NOT show bulky-specific fields
        $mech->content_lacks('Items to be collected');
        $mech->content_lacks('State pension?');
        $mech->content_lacks('Physical disability?');

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
        is $report->get_extra_field_value('round_instance_id'), '1';
        is $report->get_extra_field_value('collect_location'), 'On the doorstep';
        is $report->get_extra_field_value('sharps_collecting'), '1';
        is $report->get_extra_field_value('sharps_collect_small_quantity'), '3';
        is $report->get_extra_field_value('sharps_collect_large_quantity'), '2';
        is $report->get_extra_field_value('sharps_delivering'), '1';
        is $report->get_extra_field_value('sharps_deliver_glucose_monitor'), 'No';
        is $report->get_extra_field_value('sharps_deliver_size'), '1-litre';
        is $report->get_extra_field_value('sharps_deliver_quantity'), '5';

        $mech->clear_emails_ok();
        FixMyStreet::Script::Reports::send();
        # Email to council and email to user (former is Open311 in real life)
        $mech->email_count_is(2);
        my ( undef, $email_to_user ) = $mech->get_email;

        is $email_to_user->header('Subject'),
            'Sharps collection service - reference ' . $report->id;

        my $email_txt = $mech->get_text_body_from_email($email_to_user);
        like $email_txt, qr/Thank you for booking a sharps collection/;

        like $email_txt, qr/Number of 1-litre boxes: 3/;
        like $email_txt, qr/Number of 5-litre boxes: 2/;
        like $email_txt, qr/Collection location: On the doorstep/;
        like $email_txt, qr/Glucose monitoring devices: No/;

        like $email_txt, qr/Box size: 1-litre/;
        like $email_txt, qr/Quantity: 5/;

        my $email_html = $mech->get_html_body_from_email($email_to_user);
        like $email_html, qr/Thank you for booking a sharps collection/;

        like $email_html, qr/Number of 1-litre boxes: 3/;
        like $email_html, qr/Number of 5-litre boxes: 2/;
        like $email_html, qr/Collection location: On the doorstep/;
        like $email_html, qr/Glucose monitoring devices: No/;

        like $email_html, qr/Box size: 1-litre/;
        like $email_html, qr/Quantity: 5/;

        $report->delete;
    };

    subtest 'Sharps booking with delivery only' => sub {
        $mech->get_ok('/waste/10001/sharps');
        $mech->submit_form_ok;

        # About you
        $mech->submit_form_ok(
            {   with_fields => {
                    name  => 'Bob Marge',
                    email => $user->email,
                    phone => '44 07 111 111 111',
                }
            }
        );

        # Choose date
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2025-06-27;1;' } } );

        # Collection and delivery - delivery only
        $mech->submit_form_ok(
            {   with_fields => {
                    sharps_collecting => 'No',
                    sharps_delivering => 'Yes',
                }
            }
        );

        $mech->submit_form_ok(
            {   with_fields => {
                    deliver_glucose_monitor => 'No',
                }
            }
        );

        # Delivery details
        $mech->submit_form_ok(
            {   with_fields => {
                    deliver_size => '5-litre',
                    deliver_quantity => 2,
                }
            }
        );

        # Summary page checks
        $mech->content_contains('Booking Summary');
        $mech->content_contains('Delivery details');
        $mech->content_contains('Box size');
        $mech->content_contains('5-litre');
        $mech->content_lacks('Collection details',
            'Collection details not shown when not collecting');
        $mech->content_lacks('Items to be collected');
        $mech->content_lacks('State pension?');
        $mech->content_lacks('Physical disability?');

        $mech->submit_form_ok(
            {   with_fields => {
                    tandc => 1,
                }
            }
        );

        $mech->content_contains('Sharps booking confirmed');

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
        is $report->get_extra_field_value('round_instance_id'), '1';
        is $report->get_extra_field_value('collect_location'), '';
        is $report->get_extra_field_value('sharps_collecting'), '';
        is $report->get_extra_field_value('sharps_collect_small_quantity'), '';
        is $report->get_extra_field_value('sharps_collect_large_quantity'), '';
        is $report->get_extra_field_value('sharps_delivering'), '1';
        is $report->get_extra_field_value('sharps_deliver_glucose_monitor'), 'No';
        is $report->get_extra_field_value('sharps_deliver_size'), '5-litre';
        is $report->get_extra_field_value('sharps_deliver_quantity'), '2';

        $mech->clear_emails_ok();
        FixMyStreet::Script::Reports::send();
        # Email to council and email to user (former is Open311 in real life)
        $mech->email_count_is(2);
        my ( undef, $email_to_user ) = $mech->get_email;

        my $email_txt = $mech->get_text_body_from_email($email_to_user);

        unlike $email_txt, qr/Collection details/;

        like $email_txt, qr/Box size: 5-litre/;
        like $email_txt, qr/Quantity: 2/;

        my $email_html = $mech->get_html_body_from_email($email_to_user);

        unlike $email_html, qr/Collection details/;

        like $email_html, qr/Box size: 5-litre/;
        like $email_html, qr/Quantity: 2/;

        $report->delete;
    };

    subtest 'Sharps booking with collection only' => sub {
        $mech->get_ok('/waste/10001/sharps');
        $mech->submit_form_ok;

        # About you
        $mech->submit_form_ok(
            {   with_fields => {
                    name  => 'Bob Marge',
                    email => $user->email,
                    phone => '44 07 111 111 111',
                }
            }
        );

        # Choose date
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2025-06-27;1;' } } );

        # Collection and delivery - collection only
        $mech->submit_form_ok(
            {   with_fields => {
                    sharps_collecting => 'Yes',
                    sharps_delivering => 'No',
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
                    collect_location => 'Somewhere else',
                    collect_location_other => 'With the cat',
                }
            }
        );

        # Summary page checks
        $mech->content_contains('Collection details');
        $mech->content_contains('Number of 1-litre boxes');
        $mech->content_contains('Number of 5-litre boxes');
        $mech->content_contains('Collection location');
        $mech->content_contains('Somewhere else');
        $mech->content_contains('With the cat');
        $mech->content_lacks('Delivery details');

        $mech->submit_form_ok(
            {   with_fields => {
                    tandc => 1,
                }
            }
        );

        $mech->content_contains('Sharps booking confirmed');

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
        is $report->get_extra_field_value('round_instance_id'), '1';
        is $report->get_extra_field_value('collect_location'), 'Somewhere else';
        is $report->get_extra_field_value('collect_location_other'), 'With the cat';
        is $report->get_extra_field_value('sharps_collecting'), '1';
        is $report->get_extra_field_value('sharps_collect_small_quantity'), '3';
        is $report->get_extra_field_value('sharps_collect_large_quantity'), '2';
        is $report->get_extra_field_value('sharps_delivering'), '';
        is $report->get_extra_field_value('sharps_deliver_glucose_monitor'), '';
        is $report->get_extra_field_value('sharps_deliver_size'), '';
        is $report->get_extra_field_value('sharps_deliver_quantity'), '';

        $mech->clear_emails_ok();
        FixMyStreet::Script::Reports::send();
        # Email to council and email to user (former is Open311 in real life)
        $mech->email_count_is(2);
        my ( undef, $email_to_user ) = $mech->get_email;

        my $email_txt = $mech->get_text_body_from_email($email_to_user);

        like $email_txt, qr/Number of 1-litre boxes: 3/;
        like $email_txt, qr/Number of 5-litre boxes: 2/;
        like $email_txt, qr/Collection location: Somewhere else/;
        like $email_txt, qr/Further access details: With the cat/;

        unlike $email_txt, qr/Delivery details/;

        my $email_html = $mech->get_html_body_from_email($email_to_user);

        like $email_html, qr/Number of 1-litre boxes: 3/;
        like $email_html, qr/Number of 5-litre boxes: 2/;
        like $email_html, qr/Collection location: Somewhere else/;
        like $email_html, qr/Further access details: With the cat/;

        unlike $email_html, qr/Delivery details/;

        $report->delete;
    };

    subtest 'All eligible property classes show sharps section' => sub {
        my %eligible = (
            10001 => 'RD',
            10005 => 'CE',
            10006 => 'RH',
            10007 => 'RI',
            10008 => 'RE',
        );
        for my $uprn ( sort keys %eligible ) {
            my $class = $eligible{$uprn};
            $mech->get_ok("/waste/$uprn");
            $mech->content_contains('id="sharps"', "$class-class property shows sharps section");
            $mech->content_contains('Arrange a sharps collection', "$class-class property shows sharps sidebar link");
            $mech->get("/waste/$uprn/sharps");
            is $mech->uri->path, "/waste/$uprn/sharps", "$class-class property can access sharps form";
        }
    };

    subtest 'Ineligible property class cannot access sharps' => sub {
        $mech->get_ok('/waste/10009');
        $mech->content_lacks('id="sharps"', 'Non-eligible property has no sharps section');
        $mech->content_lacks('Arrange a sharps collection', 'Non-eligible property has no sharps sidebar link');

        $mech->get('/waste/10009/sharps');
        is $mech->res->previous->code, 302, 'Accessing sharps form redirects';
        is $mech->uri->path, '/waste/10009', 'Redirected back to property page';
    };
};

done_testing;
