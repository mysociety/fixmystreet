use utf8;
use Test::MockModule;
use Test::MockTime 'set_fixed_time';
use FixMyStreet::TestMech;
use Path::Tiny;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;
my $sample_file = path(__FILE__)->parent->child("sample.jpg");
my $sample_file_2 = path(__FILE__)->parent->child("sample2.jpg");
my $minimum_charge = 500;

my $user = $mech->create_user_ok('bob@example.org');

my $body = $mech->create_body_ok( 2482, 'Bromley Council',
    {}, { cobrand => 'bromley' } );
$body->set_extra_metadata(
    wasteworks_config => {
        per_item_costs => 1,
        per_item_min_collection_price => $minimum_charge,
        items_per_collection_max => 8,
        show_location_page => 'users',
        item_list => [
            { bartec_id => '83', name => 'Bath', price_Domestic => 1000, price_Trade => 2000 },
            { bartec_id => '84', name => 'Bathroom Cabinet /Shower Screen', price_Domestic => 1000, price_Trade => 2000 },
            { bartec_id => '85', name => 'Bicycle', price_Domestic => 1000, price_Trade => 2000 },
            { bartec_id => '3', name => 'BBQ', price_Domestic => 1000, price_Trade => 2000 },
            { bartec_id => '6', name => 'Bookcase, Shelving Unit', price_Domestic => 1000, price_Trade => 2000 },
        ],
    },
);
$body->update;

my $staff_user = $mech->create_user_ok('bromley@example.org', name => 'Council User', from_body => $body);
$body->update( { comment_user_id => $staff_user->id } );

my $echo = Test::MockModule->new('Integrations::Echo');

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste'], extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact(
    { category => 'Bulky collection', email => '2175@test.com' },
    { code => 'Collection_Date' },
    { code => 'Exact_Location' },
    { code => 'payment' },
    { code => 'payment_method' },
    { code => 'Image' },
    { code => 'Bulky_Collection_Details_Item' },
    { code => 'Bulky_Collection_Details_Description' },
    { code => 'Bulky_Collection_Details_Qty' },
    { code => 'GUID' },
    { code => 'reservation' },
);

sub domestic_waste_service_units {
    my ($self, $service_id) = @_;
    return [ {
        Id => 1,
        ServiceId => 531,
    } ]
}

sub trade_waste_service_units {
    my ($self, $service_id) = @_;
    return [ {
        Id => 1,
        ServiceId => 532,
    } ]
}

sub non_trade_or_domestic_waste_service_units {
    my ($self, $service_id) = @_;
    return [ {
        Id => 1,
        ServiceId => 533, # Random ServiceId for test
    } ]
}

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'bromley',
    COBRAND_FEATURES => {
        bulky_contact_email => { bromley => 'bulkycontact@example.org' },
        waste => { bromley => 1 },
        waste_features => {
            bromley => {
                bulky_trade_service_id => 532,
                bulky_enabled => 1,
                bulky_tandc_link => 'tandc_link',
                bulky_quantity_1_code => 2,
                bulky_cancel_no_payment_minutes => 30,
                bulky_missed => 1,
            },
        },
        echo => {
            bromley => {
                bulky_service_id => 413,
                bulky_event_type_id => 2175,
                url => 'http://example.org',
            },
        },
        payment_gateway => {
            bromley => {
                cc_url => 'http://example.com',
                hmac => '1234',
                hmac_id => '1234',
                scpID => '1234',
                company_name => 'rbk',
                form_name => 'rbk_user_form',
                staff_form_name => 'rbk_staff_form',
                customer_ref => 'customer-ref',
            },
        },
    },
}, sub {
    my $lwp = Test::MockModule->new('LWP::UserAgent');
    $echo->mock( 'CancelReservedSlotsForEvent', sub { [] } );
    $echo->mock( 'GetTasks', sub { [] } );
    $echo->mock( 'GetEventsForObject', sub { [] } );
    $echo->mock( 'FindPoints',sub { [
        {
            Description => '2 Example Street, Bromley, BR1 1AF',
            Id => '12345',
            SharedRef  => { Value => { anyType => 1000000002 } }
        }
    ] });
    $echo->mock('GetPointAddress', sub {
        return {
            Id  => '12345',
            PointAddressType => { Id   => 1, Name => 'Detached', },
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            Coordinates => { GeoPoint => { Latitude => 51.402092, Longitude => 0.015783 } },
            Description => '2 Example Street, Bromley, BR1 1AF',
        };
    });
    $echo->mock('GetServiceUnitsForObject', \&domestic_waste_service_units );
    $echo->mock('ReserveAvailableSlotsForEvent', sub {
        my ($self, $service, $event_type, $property, $guid, $start, $end) = @_;
        is $service, 413;
        is $event_type, 2175;
        is $property, 12345;
        return [
        {
            StartDate => { DateTime => '2023-07-01T00:00:00Z' },
            EndDate => { DateTime => '2023-07-02T00:00:00Z' },
            Expiry => { DateTime => '2023-06-25T10:10:00Z' },
            Reference => 'reserve1==',
        }, {
            StartDate => { DateTime => '2023-07-08T00:00:00Z' },
            EndDate => { DateTime => '2023-07-09T00:00:00Z' },
            Expiry => { DateTime => '2023-06-25T10:10:00Z' },
            Reference => 'reserve2==',
        }, {
            StartDate => { DateTime => '2023-07-15T00:00:00Z' },
            EndDate => { DateTime => '2023-07-16T00:00:00Z' },
            Expiry => { DateTime => '2023-06-25T10:10:00Z' },
            Reference => 'reserve3==',
        },
    ] });

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

    subtest 'Ineligible/Eligible property' => sub {

        $echo->mock('GetServiceUnitsForObject', \&non_trade_or_domestic_waste_service_units );
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'BR1 1AF' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );

        $mech->content_lacks('Bulky Waste');
        $echo->mock('GetServiceUnitsForObject', \&domestic_waste_service_units );
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'BR1 1AF' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );

        $mech->content_contains('Bulky Waste');
        $mech->submit_form_ok; # 'Book Collection'
        $mech->content_contains( 'Before you start your booking',
            'Should be able to access the booking form' );
    };

    my $report;
    subtest 'Bulky goods collection booking' => sub {
        $mech->get_ok('/waste/12345/bulky');

        subtest 'Intro page' => sub {
            $mech->content_contains('Book bulky goods collection');
            $mech->content_contains('Before you start your booking');
            $mech->content_contains('You can request up to <strong>eight items per collection');
            $mech->submit_form_ok;
        };

        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('01 July');
        $mech->content_contains('08 July');
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2023-07-01T00:00:00;reserve1==;2023-06-25T10:10:00' } }
        );
        $mech->submit_form_ok(
            {   with_fields => {
                    'item_1' => 'BBQ',
                    'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                    'item_2' => 'Bicycle',
                    'item_3' => 'Bath',
                },
            },
        );
        $mech->submit_form_ok({ with_fields => {
            location => 'in the middle of the drive',
            'location_photo' => [ $sample_file_2, undef, Content_Type => 'image/jpeg' ],
        }});

        sub test_summary {
            $mech->content_contains('Booking Summary');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('you can add up to 5 more items');
            $mech->content_contains('£30.00');
            $mech->content_contains("<dd>01 July</dd>");
            $mech->content_contains("07:00 on 01 July 2023");
        }
        subtest 'Summary page' => \&test_summary;

        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        my $email = $mech->get_email;
        my $url = $mech->get_link_from_email($email);
        $mech->get_ok($url);

        subtest 'Payment page' => sub {
            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky goods collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->state, 'confirmed', 'report confirmed';

            is $sent_params->{items}[0]{amount}, 3000, 'correct amount used';
            is $sent_params->{items}[0]{reference}, 'customer-ref';
            is $sent_params->{items}[0]{lineId}, $new_report->id;

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

            my $update = $new_report->comments->first;
            is $update->state, 'confirmed';
            is $update->text, 'Payment confirmed, reference 54321';
        };

        subtest 'Confirmation page' => sub {
            $mech->content_contains('Bulky collection booking confirmed');

            $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            is $report->detail, "Address: 2 Example Street, Bromley, BR1 1AF";
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky goods collection';
            is $report->get_extra_field_value('uprn'), 1000000002;
            is $report->get_extra_field_value('property_id'), '12345';
            is $report->get_extra_field_value('Exact_Location'), 'in the middle of the drive';
            is $report->get_extra_field_value('Bulky_Collection_Details_Qty'), '2::2::2';
            is $report->get_extra_field_value('Bulky_Collection_Details_Item'), '3::85::83';
            is $report->get_extra_field_value('Bulky_Collection_Details_Description'), 'BBQ::Bicycle::Bath';
            like $report->get_extra_field_value('GUID'), qr/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/;
            is $report->get_extra_field_value('reservation'), 'reserve1==';
            # A location image is first followed by the item ones.
            is $report->get_extra_field_value('Image'),
                '685286eab13ad917f614937170661171b488f280.jpeg::74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg::::';
            is $report->photo,
                '685286eab13ad917f614937170661171b488f280.jpeg,74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';
        };
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        $report->confirmed('2023-08-30T00:00:00');
        $report->update;
        my $id = $report->id;
        my $property_id = $report->get_extra_field_value('property_id');
        subtest 'Email confirmation' => sub {
            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();
            my @emails = $mech->get_email;
            my $confirmation_email_txt = $mech->get_text_body_from_email($emails[1]);
            my $confirmation_email_html = $mech->get_html_body_from_email($emails[1]);
            like $confirmation_email_txt, qr/Date booking made: 30 August/, 'Includes booking date';
            like $confirmation_email_txt, qr/The report's reference number is $id/, 'Includes reference number';
            like $confirmation_email_txt, qr/Items to be collected:/, 'Includes header for items';
            like $confirmation_email_txt, qr/- BBQ/, 'Includes item 1';
            like $confirmation_email_txt, qr/- Bicycle/, 'Includes item 2';
            like $confirmation_email_txt, qr/- Bath/, 'Includes item 3';
            like $confirmation_email_txt, qr/Total cost: £30.00/, 'Includes price';
            like $confirmation_email_txt, qr/Address: 2 Example Street, Bromley, BR1 1AF/, 'Includes collection address';
            like $confirmation_email_txt, qr/Collection date: 01 July/, 'Includes collection date';
            like $confirmation_email_txt, qr#http://bromley.example.org/waste/12345/bulky/cancel/$id#, 'Includes cancellation link';
            like $confirmation_email_txt, qr/Please check you have read the terms and conditions tandc_link/, 'Includes terms and conditions';
            like $confirmation_email_html, qr/Date booking made: 30 August/, 'Includes booking date (html mail)';
            like $confirmation_email_html, qr#The report's reference number is <strong>$id</strong>#, 'Includes reference number (html mail)';
            like $confirmation_email_html, qr/Items to be collected:/, 'Includes header for items (html mail)';
            like $confirmation_email_html, qr/BBQ/, 'Includes item 1 (html mail)';
            like $confirmation_email_html, qr/Bicycle/, 'Includes item 2 (html mail)';
            like $confirmation_email_html, qr/Bath/, 'Includes item 3 (html mail)';
            like $confirmation_email_html, qr/Total cost: £30.00/, 'Includes price (html mail)';
            like $confirmation_email_html, qr/Address: 2 Example Street, Bromley, BR1 1AF/, 'Includes collection address (html mail)';
            like $confirmation_email_html, qr/Collection date: 01 July/, 'Includes collection date (html mail)';
            like $confirmation_email_html, qr#http://bromley.example.org/waste/12345/bulky/cancel/$id#, 'Includes cancellation link (html mail)';
            like $confirmation_email_html, qr/a href="tandc_link"/, 'Includes terms and conditions (html mail)';
            $mech->clear_emails_ok;
        };

        subtest 'Reminder email' => sub {
            set_fixed_time('2023-06-28T05:44:59Z');
            my $cobrand = $body->get_cobrand_handler;
            $cobrand->bulky_reminders;
            my $email = $mech->get_email;
            my $confirmation_email_txt = $mech->get_text_body_from_email($email);
            my $confirmation_email_html = $mech->get_html_body_from_email($email);
            like $confirmation_email_txt, qr/Thank you for booking a bulky waste collection with Bromley Council/, 'Includes Bromley greeting';
            like $confirmation_email_txt, qr/The report's reference number is $id/, 'Includes reference number';
            like $confirmation_email_txt, qr/Address: 2 Example Street, Bromley, BR1 1AF/, 'Includes collection address';
            like $confirmation_email_txt, qr/Collection date: 01 July/, 'Includes collection date';
            like $confirmation_email_txt, qr/- BBQ/, 'Includes item 1';
            like $confirmation_email_txt, qr/- Bicycle/, 'Includes item 2';
            like $confirmation_email_txt, qr/- Bath/, 'Includes item 3';
            like $confirmation_email_txt, qr#http://bromley.example.org/waste/12345/bulky/cancel/$id#, 'Includes cancellation link';
            like $confirmation_email_html, qr/Thank you for booking a bulky waste collection with Bromley Council/, 'Includes Bromley greeting (html mail)';
            like $confirmation_email_html, qr#The report's reference number is <strong>$id</strong>#, 'Includes reference number (html mail)';
            like $confirmation_email_html, qr/Address: 2 Example Street, Bromley, BR1 1AF/, 'Includes collection address (html mail)';
            like $confirmation_email_html, qr/Collection date: 01 July/, 'Includes collection date (html mail)';
            like $confirmation_email_html, qr/BBQ/, 'Includes item 1 (html mail)';
            like $confirmation_email_html, qr/Bicycle/, 'Includes item 2 (html mail)';
            like $confirmation_email_html, qr/Bath/, 'Includes item 3 (html mail)';
            like $confirmation_email_html, qr#http://bromley.example.org/waste/12345/bulky/cancel/$id#, 'Includes cancellation link (html mail)';
            $mech->clear_emails_ok;
        };
    };


    subtest 'Bulky goods collection viewing' => sub {
        subtest 'View own booking' => sub {
            $mech->log_in_ok($report->user->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('2 Example Street, Bromley, BR1 1AF');
            $mech->content_lacks('Please read carefully all the details');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('you can add up to 5 more items');
            $mech->content_contains('£30.00');
            $mech->content_contains('01 July');
            $mech->content_lacks('Request a bulky waste collection');
            $mech->content_contains('Your bulky waste collection');
            $mech->content_contains('Show upcoming bin days');
        };

        subtest "Can follow link to booking from bin days page" => sub {
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { text_regex => qr/Check collection details/i, }, "follow 'Check collection...' link" );
            is $mech->uri->path, '/report/' . $report->id , 'Redirected to waste base page';
        };

        subtest 'Missed collections' => sub {
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('Report a bulky waste collection as missed',
                "Can't report missing when no closed collection event");
            # Closed collection event.
            $echo->mock( 'GetEventsForObject', sub { [ {
                EventTypeId => 2175,
                ResolvedDate => { DateTime => '2023-07-02T00:00:00Z' },
            } ] } );
            $mech->get_ok('/waste/12345');
            set_fixed_time('2023-07-04T08:00:00Z');
            $mech->content_contains('Report a bulky waste collection as missed',
                'Can report missing when closed collection event and within two working days');
            set_fixed_time('2023-07-05T08:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('Report a bulky waste collection as missed',
                "Can't report missing when closed collection but after two working days");
        };

        # Collection time: 2023-07-01T:07:00:00
        my $full_refund_time = '2023-06-30T05:59:59Z'; # 06:59:59 UK time
        my $partial_refund_time = '2023-07-01T05:59:59Z'; # 06:59:59 UK time

        # Consider report to have been sent.
        $report->external_id('Echo-123');
        $report->update;

        subtest 'Cancel booking' => sub {
            $mech->log_in_ok($report->user->email);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_lacks('This collection has been cancelled');

            set_fixed_time($full_refund_time);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains("07:00 on 01 July 2023");
            $mech->content_contains('/waste/12345/bulky/cancel/' . $report->id);
            $mech->content_contains('Cancel this booking');
            $mech->content_contains('You can get a full refund if cancelled by 7am on the day prior to your collection');
            $mech->content_contains(
                'Cancellations within 24 hours of collection are only eligible for ' .
                'a partial refund for any amount paid over the minimum charge.'
            );

            $mech->clear_emails_ok();

            subtest 'Refund info' => sub {
                $mech->get_ok('/waste/12345/bulky/cancel/' . $report->id);
                $mech->content_contains('If you cancel you will be refunded £30.00');

                set_fixed_time($partial_refund_time);
                $report->update_extra_field({ name => 'payment', value => $minimum_charge });
                $report->update;
                $mech->get_ok('/waste/12345/bulky/cancel/' . $report->id);
                $mech->content_contains(
                    'Since you paid no more than the minimum charge you ' .
                    'are not eligible for a refund if you cancel this booking.'
                );
                $report->update_extra_field({ name => 'payment', value => $minimum_charge + 1 });
                $report->update;
                $mech->get_ok('/waste/12345/bulky/cancel/' . $report->id);
                $mech->content_contains(
                    'Cancellations within 24 hours of collection are only eligibile to ' .
                    'be refunded the amount paid above the minimum charge £5.00.'
                );
                $mech->content_contains('If you cancel you will be refunded £0.01.');
            };

            subtest 'Sends refund email' => sub {
                $mech->get_ok('/waste/12345/bulky/cancel/' . $report->id);
                $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
                $mech->content_contains('Your booking has been cancelled');

                my $email = $mech->get_email;

                is $email->header('Subject'),
                    'Refund requested for cancelled bulky goods collection ' . $report->id,
                    'Correct subject';
                is $email->header('To'),
                    '"Bromley Council" <bulkycontact@example.org>',
                    'Correct recipient';

                my $text = $email->as_string;

                # =C2=A3 is the quoted printable for '£'.
                like $text, qr/Payment Amount: =C2=A35.01/, "Correct payment amount";
                like $text, qr/Capita SCP Response: 12345/,
                    'Correct SCP response';
                # XXX Not picking up on mocked time
                like $text, qr|Payment Date: \d{2}/\d{2}/\d{2} \d{2}:\d{2}|,
                    'Correct date format';
                like $text, qr/CAN: 123/, 'Correct CAN';
                like $text, qr/Auth Code: 112233/, 'Correct auth code';
                my $report_id = $report->id;
                like $text, qr/reference2: ${report_id}/, 'Correct reference2';
            };
        };
    };

    $report->comments->delete;
    $report->delete;

    sub test_prices {
        my ($minimum_cost, $total_cost) = @_;
        $mech->get_ok('/waste/12345');
        $mech->content_contains('From ' . $minimum_cost);
        $mech->get_ok('/waste/12345/bulky');
        $mech->submit_form_ok; # Intro page.
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2023-07-01T00:00:00;reserve1==;2023-06-25T10:10:00' } }
        );
        $mech->submit_form_ok(
            {   with_fields => {
                    'item_1' => 'BBQ',
                },
            },
        );
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->content_contains($total_cost); # Summary page.
    }

    subtest 'Different pricing depending on domestic or trade property' => sub {
        $echo->mock('GetServiceUnitsForObject', \&trade_waste_service_units );
        test_prices('£20.00', '£20.00');
        $echo->mock('GetServiceUnitsForObject', \&domestic_waste_service_units );
        test_prices('£10.00', '£10.00');
    };

    subtest 'Minimum charged enforced' => sub {
        my $cfg = $body->get_extra_metadata('wasteworks_config');
        $cfg->{per_item_min_collection_price} = 5000;
        $body->set_extra_metadata(wasteworks_config => $cfg);
        $body->update;
        test_prices('£50.00', '£50.00');
    };

    subtest "Cancel booking when no payment within 30 minutes" => sub {
        my ( $p ) = $mech->create_problems_for_body(1, $body->id, "Bulky goods collection", {
            category => "Bulky collection",
            state => "confirmed",
            external_id => "123",
            created => "2023-10-01T08:00:00Z",
            cobrand => "bromley",
        });
        $p->set_extra_metadata('payment_reference', 'test');
        $p->update;

        my $cobrand = $body->get_cobrand_handler;

        # 31 minutes after creation.
        set_fixed_time('2023-10-01T08:31:00Z');

        # Has payment - not cancelled.
        $cobrand->cancel_bulky_collections_without_payment({ commit => 1 });
        $p->discard_changes;
        is $p->state, "confirmed";
        is $p->comments->count, 0;

        # No payment - cancelled.
        $p->unset_extra_metadata('payment_reference');
        $p->update;
        $cobrand->cancel_bulky_collections_without_payment({ commit => 1});
        $p->discard_changes;
        is $p->state, "closed";
        is $p->comments->count, 1;

        my $cancellation_update = $p->comments->first;
        is $cancellation_update->text, "Booking cancelled since payment was not made in time";
        is $cancellation_update->get_extra_metadata('bulky_cancellation'), 1;
        is $cancellation_update->user_id, $staff_user->id;
    }
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
