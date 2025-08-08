use Test::MockModule;
use Test::MockObject;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $staff_user = $mech->create_user_ok('bromley@example.org', name => 'Council User');
my $body = $mech->create_body_ok( 2494, 'Bexley Council', { cobrand => 'bexley', comment_user_id => $staff_user->id } );
$staff_user->update({ from_body => $body->id });
my $user = $mech->create_user_ok( 'bob@example.org', name => 'Original Name' );

for ($body) {
    add_extra_metadata($_);
    create_contact($_);
}

my $addr_mock = Test::MockModule->new('BexleyAddresses');
# We don't actually read from the file, so just put anything that is a valid path
$addr_mock->mock( 'database_file', '/' );
my $dbi_mock = Test::MockModule->new('DBI');
$dbi_mock->mock( 'connect', sub {
    my $dbh = Test::MockObject->new;
    $dbh->mock( 'selectall_arrayref', sub { [
        {   uprn              => 10001,
            pao_start_number  => 1,
            street_descriptor => 'THE AVENUE',
        },
        {   uprn              => 10002,
            pao_start_number  => 2,
            street_descriptor => 'THE AVENUE',
        },
    ] } );
    $dbh->mock( 'selectrow_hashref', sub { {
        postcode => 'DA1 1AA',
        has_parent => 0,
        class => $_[3] == 10001 ? 'RD04' : 'C',
        pao_start_number => 1,
        street_descriptor => 'Test Street',
        town_name => 'Bexley',
    } } );
    return $dbh;
} );

my $whitespace_mock = Test::MockModule->new('Integrations::Whitespace');
sub default_mocks {
    $whitespace_mock->mock('GetSiteCollections', sub {
        [ {
            SiteServiceID          => 1,
            ServiceItemDescription => 'Non-recyclable waste',
            ServiceItemName => 'RES-180',
            ServiceName          => 'Green Wheelie Bin',
            NextCollectionDate   => '2024-02-07T00:00:00',
            SiteServiceValidFrom => '2000-01-01T00:00:00',
            SiteServiceValidTo   => '0001-01-01T00:00:00',
            RoundSchedule => 'RND-1 Mon',
        } ];
    });
    $whitespace_mock->mock(
        'GetCollectionByUprnAndDate',
        sub {
            my ( $self, $property_id, $from_date ) = @_;
            return [];
        }
    );
    $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub { });
    $whitespace_mock->mock( 'GetInCabLogsByUprn', sub { });
    $whitespace_mock->mock( 'GetSiteInfo', sub { {
        AccountSiteID   => 1,
        AccountSiteUPRN => 10001,
        Site            => {
            SiteShortAddress => ', 1, THE AVENUE, DA1 3NP',
            SiteLatitude     => 51.466707,
            SiteLongitude    => 0.181108,
        },
    } });
    $whitespace_mock->mock( 'GetSiteWorksheets', sub {});
    $whitespace_mock->mock( 'GetCollectionSlots', sub { [
        { AdHocRoundInstanceID => 1, AdHocRoundInstanceDate => '2025-06-27T00:00:00', SlotsFree => 20 },
        { AdHocRoundInstanceID => 2, AdHocRoundInstanceDate => '2025-06-30T00:00:00', SlotsFree => 20 },
        { AdHocRoundInstanceID => 3, AdHocRoundInstanceDate => '2025-07-04T00:00:00', SlotsFree => 20 },
        { AdHocRoundInstanceID => 4, AdHocRoundInstanceDate => '2025-07-05T00:00:00', SlotsFree => 20 }, # Saturday
        { AdHocRoundInstanceID => 5, AdHocRoundInstanceDate => '2025-07-07T00:00:00', SlotsFree => 0 }, # Ignore
    ] });
};

default_mocks();

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'bexley',
    COBRAND_FEATURES => {
        waste => { bexley => 1 },
        whitespace => { bexley => { url => 'http://example.org/' } },
        waste_features => {
            bexley => {
                bulky_enabled => 1,
                bulky_multiple_bookings => 1,
                bulky_tandc_link => 'tandc_link',
                bulky_contact_email => 'bulkycontact@example.org',
                bulky_cancel_no_payment_minutes => 30,
            },
        },
        payment_gateway => { bexley => {
            cc_url => 'http://example.com',
            hmac => '1234',
            hmac_id => '1234',
            scpID => '1234',
            paye_siteID => 1234,
            paye_hmac_id => 1234,
            paye_hmac => 1234,
            customer_ref => 'customer-ref',
            bulky_customer_ref => 'bulky-customer-ref',
        } },
    },
}, sub {
    subtest 'Ineligible property as no bulky service' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '10002' } } );
        $mech->content_lacks('Bulky waste');
    };

    subtest 'Eligible property as has bulky service' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '10001' } } );

        $mech->content_contains('Bulky waste');
        $mech->submit_form_ok({ form_number => 3 });
        $mech->content_contains( 'Before you start your booking',
            'Should be able to access the booking form' );
    };

    my $sent_params;
    my $call_params;
    my $pay = Test::MockModule->new('Integrations::SCP');
    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = { @_ };
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
        return {
            transactionState => 'IN_PROGRESS',
            scpReference => '12345',
            invokeResult => {
                status => 'SUCCESS',
                redirectUrl => 'http://example.org/faq'
            }
        };
    });
    $pay->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return { transactionState => 'FAILED' } if $sent_params->{scpReference} eq 'unpaid';
        return {
            transactionState => 'COMPLETE',
            paymentResult => {
                status => 'SUCCESS',
                paymentDetails => {
                    authDetails => {
                        authCode              => 112233,
                        continuousAuditNumber => 123,
                    },
                    paymentHeader => {
                        uniqueTranId => 54321
                    }
                }
            }
        };
    });

    my $paye = Test::MockModule->new('Integrations::Paye');
    $paye->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = { @_ };
    });
    $paye->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $paye->original('pay')->($self, $sent_params);
        return {
            transactionState => 'InProgress',
            apnReference => '4ab5f886-de7d-4f5b-bbd8-42151a5deb82',
            requestId => '21355',
            invokeResult => {
                status => 'Success',
                redirectUrl => 'http://paye.example.org/faq',
            }
        }
    });

    my $report;
    subtest 'Bulky goods collection booking' => sub {
        $mech->get_ok('/waste/10001/bulky');

        subtest 'Intro page' => sub {
            $mech->content_contains('Book a bulky waste collection');
            $mech->content_contains('Before you start your booking');
            $mech->content_contains('Prices start from £45.50');
            $mech->submit_form_ok;
        };
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email, phone => '44 07 111 111 111' }});
        $mech->submit_form_ok({ with_fields => { pension => 'No', disability => 'No' } });
        $mech->content_contains('4 July');
        $mech->content_contains('5 July (extra charge)');
        $mech->content_lacks('7 July');
        $mech->submit_form_ok({ with_fields => { chosen_date => '2025-07-04;3;' } });
        $mech->submit_form_ok({ form_number => 1, fields => {
            'item_1' => 'BBQ',
            'item_2' => 'Bicycle',
            'item_3' => 'Bath',
            'item_4' => 'Bath',
            'item_5' => 'Bath',
        } });
        $mech->content_contains('too many items');
        $mech->submit_form_ok({ with_fields => {
            'item_4' => '',
            'item_5' => '',
        } });
        $mech->submit_form_ok(
            {   with_fields => {
                    location => 'Front garden or driveway',
                    parking  => 'Yes - single yellow lines',
                    parking_extra_details => 'They turn red at midnight',
                }
            }
        );
        $mech->content_contains('3 items requested for collection');
        $mech->content_contains('£69.30');

        sub test_summary {
            $mech->content_contains('Booking Summary');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('£69.30');
            $mech->content_contains("<dd>Friday 04 July 2025</dd>");
            $mech->content_contains('Bob Marge', 'name shown');
            $mech->content_contains('44 07 111 111 111', 'phone shown');
        }
        sub test_summary_submission {
            # external redirects make Test::WWW::Mechanize unhappy so clone
            # the mech for the redirect
            my $mech2 = $mech->clone;
            $mech2->submit_form_ok({ with_fields => { tandc => 1 } });
            is $mech2->res->previous->code, 302, 'payments issues a redirect';
            is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";
        }

        subtest 'Summary page' => \&test_summary;
        subtest 'Summary submission' => \&test_summary_submission;

        my $catch_email;
        subtest 'Payment page' => sub {
            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky waste collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->get_extra_field_value('collection_date'), '2025-07-04', 'correct date';
            is $new_report->get_extra_field_value('round_instance_id'), '3', 'correct date';
            is $new_report->get_extra_field_value('bulky_parking'),
                "Yes - single yellow lines\n\nThey turn red at midnight",
                'correct parking info';
            is $new_report->state, 'confirmed', 'report confirmed';

            is $sent_params->{items}[0]{reference}, 'bulky-customer-ref';
            is $sent_params->{items}[0]{amount}, 6930, 'correct amount used';

            $mech->log_in_ok($new_report->user->email);
            $mech->get_ok("/waste/10001");
            $mech->content_lacks('Items to be collected');
            $mech->log_out_ok;

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();
            my @email = $mech->get_email;
            $mech->email_count_is(1); # Only email is 'email' to council
            $mech->clear_emails_ok;
            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
            FixMyStreet::Script::Reports::send();
            $catch_email = $mech->get_email;
            $mech->clear_emails_ok;
            $new_report->discard_changes;
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

            is $new_report->comments->count, 1;
            my $update = $new_report->comments->first;
            is $update->state, 'confirmed';
            is $update->text, 'Payment confirmed, reference 54321, amount £69.30';
            is $update->get_extra_metadata('fms_extra_payments'), '54321|69.30';
            FixMyStreet::Script::Alerts::send_updates();
            $mech->email_count_is(0);

            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            is $new_report->comments->count, 1;
        };

        subtest 'Bulky goods email confirmation' => sub {
            my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            my $today = $report->confirmed->strftime('%A %d %B %Y');
            my $id = $report->id;
            is $catch_email->header('Subject'), "Bulky waste collection service - reference $id";
            my $confirmation_email_txt = $mech->get_text_body_from_email($catch_email);
            my $confirmation_email_html = $mech->get_html_body_from_email($catch_email);
            like $confirmation_email_txt, qr/reference number is $id/, 'Includes reference number';
            like $confirmation_email_txt, qr/Items to be collected:/, 'Includes header for items';
            like $confirmation_email_txt, qr/- BBQ/, 'Includes item 1';
            like $confirmation_email_txt, qr/- Bicycle/, 'Includes item 2';
            like $confirmation_email_txt, qr/- Bath/, 'Includes item 3';
            like $confirmation_email_txt, qr/Total cost: £69.30/, 'Includes price';
            like $confirmation_email_txt, qr/Address: 1 Test Street, Bexley, DA1 1AA/, 'Includes collection address';
            like $confirmation_email_txt, qr/Collection date: Friday 04 July 2025/, 'Includes collection date';
            like $confirmation_email_txt, qr#http://bexley.example.org/waste/10001/bulky/cancel#, 'Includes cancellation link';
            like $confirmation_email_txt, qr/Please check you have read the terms and conditions tandc_link/, 'Includes terms and conditions';
            like $confirmation_email_html, qr#reference number is <strong>$id</strong>#, 'Includes reference number (html mail)';
            like $confirmation_email_html, qr/Items to be collected:/, 'Includes header for items (html mail)';
            like $confirmation_email_html, qr/BBQ/, 'Includes item 1 (html mail)';
            like $confirmation_email_html, qr/Bicycle/, 'Includes item 2 (html mail)';
            like $confirmation_email_html, qr/Bath/, 'Includes item 3 (html mail)';
            like $confirmation_email_html, qr/Total cost: £69.30/, 'Includes price (html mail)';
            like $confirmation_email_html, qr/Address: 1 Test Street, Bexley, DA1 1AA/, 'Includes collection address (html mail)';
            like $confirmation_email_html, qr/Collection date: Friday 04 July 2025/, 'Includes collection date (html mail)';
            like $confirmation_email_html, qr#http://bexley.example.org/waste/10001/bulky/cancel#, 'Includes cancellation link (html mail)';
            like $confirmation_email_html, qr/a href="tandc_link"/, 'Includes terms and conditions (html mail)';
        };

        subtest 'Confirmation page' => sub {
            $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            $mech->content_contains('Bulky collection booking confirmed');
            $mech->content_contains('Our contractor will collect the items you have requested on Friday 04 July 2025.');
            $mech->content_contains('Collections start from 6am.&nbsp;Please have your items ready');
            $mech->content_contains('We have emailed confirmation of your booking to pkg-tappcontrollerwaste_bexley_bulkyt-bob@example.org.');
            $mech->content_contains('If you need to contact us about your booking please use the reference:&nbsp;' . $report->id);
            $mech->content_contains('Card payment reference: 54321');
            $mech->content_contains('Show upcoming bin days');
            is $report->detail, "Address: 1 Test Street, Bexley, DA1 1AA";
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky waste collection';
            is $report->get_extra_field_value('uprn'), 10001;
            is $report->get_extra_field_value('collection_date'), '2025-07-04';
            is $report->get_extra_field_value('bulky_items'), '3::85::83';
            is $report->get_extra_field_value('property_id'), '10001';

            is $report->name, 'Bob Marge', 'correct name on report';
            is $report->get_extra_metadata('phone'), '44 07 111 111 111';
            is $report->user->name, 'Original Name';
            is $report->user->phone, undef, 'no phone on report user';
            is $report->user->email, $user->email;
        };
    };

    # Collection date: 2025-07-04
    # Time/date that is within the cancellation window:
    my $good_date = '2025-07-02T12:00:00Z';

    subtest 'Bulky goods collection viewing' => sub {
        subtest 'View own booking' => sub {
            $mech->log_in_ok($report->user->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('1 Test Street, Bexley, DA1 1AA');
            $mech->content_lacks('Please read carefully all the details');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('£69.30');
            $mech->content_contains('4 July');
            $mech->content_lacks('Request a bulky waste collection');
            $mech->content_contains('Your bulky waste collection');
            $mech->content_contains('Show upcoming bin days');
            $mech->content_contains('Bob Marge', 'name shown');
            $mech->content_contains('44 07 111 111 111', 'phone shown');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');

            set_fixed_time($good_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("4 July 2025");

            # Presence of external_id in report implies we have sent request
            $mech->content_lacks('/waste/10001/bulky/cancel');
            $mech->content_lacks('Cancel this booking');
            $report->external_id('Whitespace-123');
            $report->update;
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains('/waste/10001/bulky/cancel');
            $mech->content_contains('Cancel this booking');
        };

        subtest "Can follow link to booking from bin days page" => sub {
            $mech->get_ok('/waste/10001');
            $mech->follow_link_ok( { text_regex => qr/Check collection details/i, }, "follow 'Check collection...' link" );
            is $mech->uri->path, '/report/' . $report->id , 'Redirected to waste base page';
        };
    };

    subtest 'Bulky goods email reminders' => sub {
        # No 3 day email
        set_fixed_time('2025-07-01T05:44:59Z');
        my $cobrand = $body->get_cobrand_handler;
        $cobrand->bulky_reminders;
        $mech->email_count_is(0);
        set_fixed_time('2025-07-03T05:44:59Z');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        # Check no payment reference, no email
        $report->unset_extra_metadata('payment_reference');
        $report->update;
        $cobrand->bulky_reminders;
        $mech->email_count_is(0);
        $report->set_extra_metadata('payment_reference', 54321);
        $report->update;
        $cobrand->bulky_reminders;
        my $email = $mech->get_email;
        my $reminder_email_txt = $mech->get_text_body_from_email($email);
        my $reminder_email_html = $mech->get_html_body_from_email($email);
        like $reminder_email_txt, qr/Address: 1 Test Street, Bexley, DA1 1AA/, 'Includes collection address';
        like $reminder_email_txt, qr/Friday 04 July 2025/, 'Includes collection date';
        unlike $reminder_email_txt, qr#http://bexley.example.org/waste/10001/bulky/cancel#, 'No cancellation link';
        like $reminder_email_html, qr/Thank you for booking a bulky waste collection with London Borough of Bexley/, 'Includes Bexley greeting (html mail)';
        like $reminder_email_html, qr/Address: 1 Test Street, Bexley, DA1 1AA/, 'Includes collection address (html mail)';
        like $reminder_email_html, qr/Friday 04 July 2025/, 'Includes collection date (html mail)';
        unlike $reminder_email_html, qr#http://bexley.example.org/waste/10001/bulky/cancel#, 'No cancellation link (html mail)';
        $mech->clear_emails_ok;
    };

    subtest 'Bulky goods collection, cancelling' => sub {
        set_fixed_time($good_date);
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('This collection has been cancelled');
        $mech->content_contains("You can cancel this booking up to");
        $mech->content_contains("23:59 on 02 July 2025");
        $mech->content_contains('/waste/10001/bulky/cancel/' . $report->id);
        $mech->content_contains('Cancel this booking');

        $mech->clear_emails_ok();

        subtest 'No payment yet made' => sub {
            $report->unset_extra_metadata('payment_reference');
            $report->update;
            $mech->get_ok('/waste/10001/bulky/cancel/' . $report->id);
            $mech->content_lacks('you will receive a refund');
            $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
            $mech->content_contains('Your booking has been cancelled');

            $mech->email_count_is(0);

            $report->discard_changes;
            $report->set_extra_metadata(payment_reference => 12345);
            $report->state('confirmed');
            $report->update;
        };

        $mech->get_ok('/waste/10001/bulky/cancel/' . $report->id);
        $mech->content_like(qr{<dt>Date</dt>\s*<dd>Friday 04 July 2025</dd>});
        $mech->content_contains('BBQ');
        $mech->content_contains('receive a refund of £69.30');
        $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
        $mech->content_contains('Your booking has been cancelled');

        my $report_id = $report->id;
        my $email = $mech->get_email;

        subtest 'Sends refund email' => sub {
            is $email->header('Subject'),
                'Refund requested for cancelled bulky waste collection ' . $report->id,
                'Correct subject';
            is $email->header('To'),
                '"London Borough of Bexley" <bulkycontact@example.org>',
                'Correct recipient';

            my $text = $email->as_string;

            like $text, qr/Address: 1 Test Street, Bexley, DA1 1AA/, "Includes resident's address";
            my $name = $report->name;
            like $text, qr/Resident's Name: ${name}/, "Includes resident's name";
            my $user_email = $report->user->email;
            like $text, qr/Resident's Email: ${user_email}/, "Includes resident's email";
            # =C2=A3 is the quoted printable for '£'.
            like $text, qr/Payment Amount: =C2=A369.30/, "Correct payment amount";
            like $text, qr/Amount To Refund: =C2=A369.30/, "Correct payment amount";
            like $text, qr/Capita SCP Response: 12345/,
                'Correct SCP response';
            # XXX Not picking up on mocked time
            like $text, qr|Payment Date: \d{2}/\d{2}/\d{2} \d{2}:\d{2}|,
                'Correct date format';
            like $text, qr/CAN: 123/, 'Correct CAN';
            like $text, qr/Auth Code: 112233/, 'Correct auth code';
            like $text, qr/reference2: ${report_id}/, 'Correct reference2';
        };
    };

    subtest "Cancel booking when no payment within 30 minutes" => sub {
        my ( $p ) = $mech->create_problems_for_body(1, $body->id, "Bulky waste collection", {
            category => "Bulky collection",
            state => "confirmed",
            external_id => "123",
            created => "2023-10-01T08:00:00Z",
            cobrand => "bexley",
        });
        $p->set_extra_fields(
            { name => 'uprn', value => 'UPRN' },
            { name => 'payment_method', value => 'credit_card' },
            { name => 'payment', value => '6930' },
        );
        $p->set_extra_metadata('payment_reference', 'test');
        $p->set_extra_metadata('scpReference', 'unpaid');
        $p->update;

        my $cobrand = $body->get_cobrand_handler;

        # 31 minutes after creation.
        set_fixed_time('2023-10-01T08:31:00Z');

        subtest 'has payment - not cancelled' => sub {
            $cobrand->cancel_bulky_collections_without_payment({ commit => 1 });
            $p->discard_changes;
            is $p->state, "confirmed";
            is $p->comments->count, 0;
        };

        subtest 'No payment but made by staff - not cancelled' => sub {
            $p->set_extra_metadata( contributed_as => 'another_user' );
            $p->unset_extra_metadata('payment_reference');
            $p->update;
            $cobrand->cancel_bulky_collections_without_payment({ commit => 1 });
            $p->discard_changes;
            is $p->state, "confirmed";
            is $p->comments->count, 0;
        };

        subtest 'No payment non-staff but check shows was paid - not cancelled' => sub {
            $p->unset_extra_metadata('contributed_as');
            $p->set_extra_metadata('scpReference', 'paid');
            $p->update;
            $cobrand->cancel_bulky_collections_without_payment({ commit => 1 });
            $p->discard_changes;
            is $p->state, "confirmed";
            is $p->comments->count, 1;
            is $p->get_extra_metadata('continuousAuditNumber'), 123;
            is $p->get_extra_metadata('authCode'), 112233;
            is $p->get_extra_metadata('payment_reference'), 54321;
            is $p->get_extra_field_value('PaymentCode'), 54321;
            is $p->comments->first->text, "Payment confirmed, reference 54321, amount £69.30";
            is $p->get_extra_field_value('uprn'), 'UPRN';
        };

        subtest 'No payment non-staff and check confirms unpaid - cancelled' => sub {
            $p->set_extra_metadata('scpReference', 'unpaid');
            $p->unset_extra_metadata('payment_reference');
            $p->comments->delete;
            $p->update;
            $cobrand->cancel_bulky_collections_without_payment({ commit => 1 });
            $p->discard_changes;
            is $p->state, "cancelled";
            my $cancellation_update = $p->comments->first;
            is $cancellation_update->text, "Booking cancelled since payment was not made in time";
            is $cancellation_update->get_extra_metadata('bulky_cancellation'), 1;
            is $cancellation_update->user_id, $staff_user->id;
        };
    };

    subtest 'OAP pricing' => sub {
        $mech->get_ok('/waste/10001/bulky');
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email, phone => '44 07 111 111 111' }});
        $mech->submit_form_ok({ with_fields => { pension => 'Yes', disability => 'No' } });
        $mech->submit_form_ok({ with_fields => { chosen_date => '2025-07-04;3;' } });
        $mech->submit_form_ok({ form_number => 1, fields => { 'item_1' => 'BBQ', 'item_2' => 'Bicycle', 'item_3' => 'Bath', 'item_4' => 'Bath', 'item_5' => 'Bath' } });
        $mech->content_lacks('too many items');
        $mech->submit_form_ok({ with_fields => { parking => 'No', location => 'Front garden or driveway' } });
        $mech->content_contains('5 items requested for collection');
        $mech->content_contains('£66.00');
    };

    subtest 'Saturday pricing' => sub {
        $mech->get_ok('/waste/10001/bulky');
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email, phone => '44 07 111 111 111' }});
        $mech->submit_form_ok({ with_fields => { pension => 'No', disability => 'No' } });
        $mech->content_contains('4 July');
        $mech->content_contains('5 July');
        $mech->content_lacks('7 July');
        $mech->submit_form_ok({ with_fields => { chosen_date => '2025-07-05;4;' } });
        $mech->submit_form_ok({ form_number => 1, fields => { 'item_1' => 'BBQ', 'item_2' => 'Bicycle', 'item_3' => 'Bath', 'item_4' => 'Bath', 'item_5' => 'Bath' } });
        $mech->content_contains('too many items');
        $mech->submit_form_ok({ with_fields => { 'item_4' => '', 'item_5' => '' } });
        $mech->submit_form_ok({ with_fields => { parking => 'No', location => 'Front garden or driveway' } });
        $mech->content_contains('3 items requested for collection');
        $mech->content_contains('£89.50');
    };

    subtest 'Staff bulky collection uses paye.net with custom narrative' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/10001/bulky');
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email, phone => '44 07 111 111 111' }});
        $mech->submit_form_ok({ with_fields => { pension => 'No', disability => 'No' } });
        $mech->submit_form_ok({ with_fields => { chosen_date => '2025-07-04;3;' } });
        $mech->submit_form_ok({ form_number => 1, fields => { 'item_1' => 'BBQ' } });
        $mech->submit_form_ok(
            {   with_fields => {
                    location => 'Front garden or driveway',
                    parking  => 'Yes - single yellow lines',
                    parking_extra_details => 'They turn red at midnight',
                }
            }
        );
        my $mech2 = $mech->clone;
        $mech2->submit_form_ok({ with_fields => { tandc => 1 } });
        is $mech2->res->previous->code, 302, 'payments issues a redirect';
        like $mech2->res->previous->header('Location'), qr/paye.example.org/;

        my ($token, $report, $report_id) = get_report_from_redirect($sent_params->{returnUrl});
        is $sent_params->{items}[0]{reference}, 'bulky-customer-ref';
        is $sent_params->{narrative}, "Bulky waste - $report_id";
    };
};

done_testing;

sub get_report_from_redirect {
    my $url = shift;

    my ($report_id, $token) = ( $url =~ m#/(\d+)/([^/]+)$# );
    my $new_report = FixMyStreet::DB->resultset('Problem')->find( {
            id => $report_id,
    });

    return undef unless $new_report->get_extra_metadata('redirect_id') eq $token;
    return ($token, $new_report, $report_id);
}

sub add_extra_metadata {
    my $body = shift;

    $body->set_extra_metadata(
        wasteworks_config => {
            per_item_min_collection_price => 4550,
            show_location_page => 'users',
            item_list => [
                { bartec_id => '83', name => 'Bath', points => 4 },
                { bartec_id => '84', name => 'Bathroom Cabinet /Shower Screen', points => 3 },
                { bartec_id => '85', name => 'Bicycle', points => 3 },
                { bartec_id => '3', name => 'BBQ', points => 2 },
                { bartec_id => '6', name => 'Bookcase, Shelving Unit', points => 1 },
            ],
            points => {
                no => {
                    no => [
                        { min => 1, price => 4550 },
                        { min => 9, price => 6930 },
                        { min => 13, price => 'max' },
                    ],
                    yes => [
                        { min => 1, price => 4330 },
                        { min => 17, price => 6600 },
                        { min => 25, price => 'max' },
                    ],
                },
                yes => {
                    no => [
                        { min => 1, price => 6550 },
                        { min => 9, price => 8950 },
                        { min => 13, price => 'max' },
                    ],
                    yes => [
                        { min => 1, price => 6550 },
                        { min => 17, price => 8950 },
                        { min => 25, price => 'max' },
                    ],
                },
            },
        },
    );
    $body->update;
}

sub create_contact {
    my ($body) = @_;
    my ($params, @extra) = &_contact_extra_data;

    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste'], extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

sub _contact_extra_data {
    return (
        { category => 'Bulky collection', email => 'bulky@test.com' },
        { code => 'payment' },
        { code => 'payment_method' },
        { code => 'collection_date' },
        { code => 'round_instance_id' },
        { code => 'bulky_items' },
        { code => 'pension' },
        { code => 'disability' },
        { code => 'bulky_location' },
        { code => 'bulky_parking' },
    );
}
