# Must be at top
use Test::MockTime 'set_fixed_time';

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
        my $got_service_id;
        $whitespace_mock->mock('GetCollectionSlots', sub {
            my ($self, $uprn, $from, $to, $service_id) = @_;
            $got_service_id = $service_id;
            return $slots_default;
        });
        $mech->submit_form_ok(
            {   with_fields => {
                    name  => 'Bob Marge',
                    email => $user->email,
                    phone => '44 07 111 111 111',
                }
            }
        );
        is $got_service_id, 359, 'Uses sharps service ID for GetCollectionSlots';

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
        # Manually set external ID on report
        $report->external_id('Whitespace-123');
        $report->update;
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

        unlike $email_txt, qr/terms and conditions/;

        my $email_html = $mech->get_html_body_from_email($email_to_user);
        like $email_html, qr/Thank you for booking a sharps collection/;

        like $email_html, qr/Number of 1-litre boxes: 3/;
        like $email_html, qr/Number of 5-litre boxes: 2/;
        like $email_html, qr/Collection location: On the doorstep/;
        like $email_html, qr/Glucose monitoring devices: No/;

        like $email_html, qr/Box size: 1-litre/;
        like $email_html, qr/Quantity: 5/;

        unlike $email_html, qr/terms and conditions/;

        set_fixed_time('2025-06-01T12:00:00Z');

        subtest 'View sharps report' => sub {
            note 'Sharps section on bin days page shows same options because no user logged in';
            $mech->get_ok('/waste/10001');
            $mech->content_contains('You need to sign in to see the full details of this property.');
            $mech->content_contains('Book a collection');
            $mech->content_lacks('View existing collections');
            $mech->content_lacks('Check booking details');

            $mech->get( '/report/' . $report->id );
            is $mech->res->code, 403, 'cannot view if not logged in';

            $mech->log_in_ok( $report->user->email );
            $mech->get_ok('/waste/10001');
            $mech->content_lacks('You need to sign in to see the full details of this property.');
            $mech->content_contains('Book a collection');
            $mech->content_lacks('View existing collections');
            $mech->content_contains('Check booking details');

            $mech->get_ok( '/report/' . $report->id );

            # Report page should show sharps-specific details
            $mech->text_contains('Your sharps booking');

            $mech->text_contains('Collection details');
            $mech->text_contains('Number of 1-litre boxes3');
            $mech->text_contains('Number of 5-litre boxes2');
            $mech->text_contains('Collection locationOn the doorstep');
            $mech->text_contains('Glucose monitoring devicesNo');

            $mech->text_contains('Delivery details');
            $mech->text_contains('Box size1-litre');
            $mech->text_contains('Quantity5');

            # ... but NOT show bulky-specific details
            $mech->content_lacks('Items to be collected');
            $mech->content_lacks('State pension?');
            $mech->content_lacks('Physical disability?');

            $mech->content_contains('Cancel this booking');
        };

        subtest 'Cancel sharps collection' => sub {
            $mech->log_out_ok;

            $mech->get_ok('/waste/10001');
            $mech->content_lacks('Cancel booking');
            $mech->get( '/waste/10001/sharps/cancel/' . $report->id );
            $mech->text_contains('Sign in  or create an account', 'must sign in to cancel');

            $mech->log_in_ok( $report->user->email );

            $mech->get_ok('/waste/10001');
            $mech->content_contains('Cancel booking');

            $mech->get_ok( '/waste/10001/sharps/cancel/' . $report->id );

            $mech->text_contains('Cancel your sharps booking');
            $mech->text_contains('I confirm I wish to cancel my sharps booking');

            $mech->text_contains('Collection details');
            $mech->text_contains('Number of 1-litre boxes3');
            $mech->text_contains('Number of 5-litre boxes2');
            $mech->text_contains('Collection locationOn the doorstep');
            $mech->text_contains('Glucose monitoring devicesNo');

            $mech->text_contains('Delivery details');
            $mech->text_contains('Box size1-litre');
            $mech->text_contains('Quantity5');

            $mech->submit_form_ok( { with_fields => { confirm => 1 } } );

            $mech->text_contains('Your booking has been cancelled');
            my $id = $report->id;
            $mech->text_like(qr/your sharps booking cancellation.*$id/);

            $report->discard_changes;

            like $report->detail, qr/Cancelled at user request/;
            is $report->state, 'cancelled';
        };

        $mech->log_out_ok;

        $mech->delete_problems_for_body($body->id);
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

    subtest 'Saturday dates do not show extra charge note' => sub {
        $mech->get_ok('/waste/10001/sharps');
        $mech->submit_form_ok;

        $mech->submit_form_ok(
            {   with_fields => {
                    name  => 'Bob Marge',
                    email => $user->email,
                    phone => '44 07 111 111 111',
                }
            }
        );

        $mech->content_contains('Choose date for collection');
        $mech->content_contains('5 July', 'Saturday date is shown');
        $mech->content_lacks('extra charge', 'Saturday does not show extra charge on sharps form');
    };

    subtest 'Sharps collection email reminders' => sub {
        $mech->get_ok('/waste/10001/sharps');
        $mech->submit_form_ok; # intro page
        $mech->submit_form_ok({ with_fields => {
            name => 'Bob Marge', email => $user->email, phone => '44 07 111 111 111',
        }});
        $mech->submit_form_ok({ with_fields => { chosen_date => '2025-06-27;1;' } });
        $mech->submit_form_ok({ with_fields => {
            sharps_collecting => 'Yes', sharps_delivering => 'No',
        }});
        $mech->submit_form_ok({ with_fields => {
            collect_small_quantity => 3, collect_large_quantity => 2,
        }});
        $mech->submit_form_ok({ with_fields => {
            collect_location => 'On the doorstep',
        }});
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $mech->clear_emails_ok;

        my $report = FixMyStreet::DB->resultset('Problem')->search(
            undef, { order_by => { -desc => 'id' } }
        )->first;

        my $cobrand = $body->get_cobrand_handler;

        # Collection date is 2025-06-27. Too early — no reminder 3 days before.
        set_fixed_time('2025-06-24T05:44:59Z');
        $cobrand->bulky_reminders;
        $mech->email_count_is(0, 'No reminder 3 days before collection');

        # One day before — reminder is sent
        set_fixed_time('2025-06-26T05:44:59Z');
        $cobrand->bulky_reminders;
        my $email = $mech->get_email;

        is $email->header('Subject'),
            'Sharps collection reminder - reference ' . $report->id,
            'Correct reminder subject';

        my $txt  = $mech->get_text_body_from_email($email);
        my $html = $mech->get_html_body_from_email($email);

        like $txt, qr/This is a reminder that your collection is tomorrow/,
            'Reminder email distinguishable from confirmation (txt)';
        like $txt, qr/${\$report->id}/, 'Includes request number (txt)';
        like $txt, qr/Address:.*DA1 3NP/, 'Includes collection address (txt)';
        like $txt, qr/Friday 27 June 2025/, 'Includes collection date (txt)';
        like $txt, qr/Number of 1-litre boxes: 3/, 'Includes 1-litre box count (txt)';
        like $txt, qr/Number of 5-litre boxes: 2/, 'Includes 5-litre box count (txt)';
        unlike $txt, qr{/waste/10001/sharps/cancel/}, 'No cancel link in reminder (txt)';

        like $html, qr/Friday 27 June 2025/, 'Includes collection date (html)';
        unlike $html, qr{/waste/10001/sharps/cancel/}, 'No cancel link in reminder (html)';
        $mech->clear_emails_ok;

        # No second reminder sent
        $cobrand->bulky_reminders;
        $mech->email_count_is(0, 'No duplicate reminder sent');
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
