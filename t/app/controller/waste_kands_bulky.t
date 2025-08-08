use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use Path::Tiny;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;
my $sample_file = path(__FILE__)->parent->child("sample.jpg");

my $user
    = $mech->create_user_ok( 'bob@example.org', name => 'Original Name' );
my $body_user = $mech->create_user_ok('body@example.org');

my $body = $mech->create_body_ok( 2480, 'Kingston upon Thames Council',
    { comment_user => $body_user, cobrand => 'kingston' } );

my $contact = $mech->create_contact_ok(body => $body, ( category => 'Report missed collection', email => 'missed@example.org' ), group => ['Waste'], extra => { type => 'waste' });
  $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        { code => 'Exact_Location', required => 0, automated => 'hidden_field' },
        { code => 'Original_Event_ID', required => 0, automated => 'hidden_field' },
        { code => 'Notes', required => 0, automated => 'hidden_field' },
    );
$contact->update;

my $contact_centre_user = $mech->create_user_ok('contact@example.org', from_body => $body, email_verified => 1, name => 'Contact 1');

my $sutton = $mech->create_body_ok( 2498, 'Sutton Borough Council', { cobrand => 'sutton' } );
my $sutton_staff = $mech->create_user_ok('sutton_staff@example.org', from_body => $sutton->id);

for ($body, $sutton) {
    add_extra_metadata($_);
    create_bulky_contact($_);
}

create_contact($sutton, { category => 'Complaint against time', email => '3134' },
    { code => 'Notes', required => 1, automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
    { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
    { code => 'original_ref', required => 0, automated => 'hidden_field' },
    { code => 'missed_guid', required => 0, automated => 'hidden_field' },
);

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'kingston',
    COBRAND_FEATURES => {
        waste => { kingston => 1 },
        waste_features => {
            kingston => {
                bulky_enabled => 1,
                bulky_missed => 1,
                bulky_tandc_link => 'tandc_link',
                echo_update_failure_email => 'fail@example.com',
            },
        },
        echo => {
            kingston => {
                bulky_address_types => [ 1, 7 ],
                bulky_service_id => 986,
                bulky_event_type_id => 3130,
                url => 'http://example.org',
                nlpg => 'https://example.com/%s',
            },
        },
        payment_gateway => { kingston => {
            cc_url => 'http://example.com',
            hmac => '1234',
            hmac_id => '1234',
            scpID => '1234',
            company_name => 'rbk',
            customer_ref => 'customer-ref',
            bulky_customer_ref => 'customer-ref-bulky',
        } },
    },
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 2238}] } );
    $echo->mock( 'GetTasks',                 sub { [] } );
    $echo->mock( 'GetEventsForObject',       sub { [] } );
    $echo->mock( 'CancelReservedSlotsForEvent', sub {
        my (undef, $guid) = @_;
        ok $guid, 'non-nil GUID passed to CancelReservedSlotsForEvent';
    } );
    $echo->mock(
        'FindPoints',
        sub {
            [   {   Description => '2 Example Street, Kingston, KT1 1AA',
                    Id          => '12345',
                    SharedRef   => { Value => { anyType => 1000000002 } }
                },
            ]
        }
    );

    # Redefine call for this one as we want to test the rest of the
    # ReserveAvailableSlotsForEvent function
    $echo->redefine( call => sub {
        is $_[1], 'ReserveAvailableSlotsForEvent';
        is $_[2], 'event';
        is $_[3]->{EventTypeId}, 3130;
        is $_[3]->{ServiceId}, 986;
        is $_[3]->{Data}[0]{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value}, 1842;
        # Dig down to the property ID
        is $_[3]->{EventObjects}{EventObject}{ObjectRef}{Value}[0]{'msArray:anyType'}->value, 12345;
        return {
            ReservedTaskInfo => [
                {
                    Description => 'TaskType_1234',
                    ReservedSlots => {
                        ReservedSlot => [
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
                        ]
                    }
                },
                {
                    Description => 'TaskType_5678',
                    ReservedSlots => {
                        ReservedSlot => [
                            {
                                StartDate => { DateTime => '2023-07-01T00:00:00Z' },
                                EndDate => { DateTime => '2023-07-02T00:00:00Z' },
                                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                                Reference => 'reserve4==',
                            }, {
                                StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                                EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                                Reference => 'reserve5==',
                            }, {
                                StartDate => { DateTime => '2023-07-22T00:00:00Z' },
                                EndDate => { DateTime => '2023-07-16T00:00:00Z' },
                                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                                Reference => 'reserve6==',
                            },
                        ]
                    }
                }
            ]
        };
    });

    subtest 'Ineligible property' => sub {
        $echo->mock(
            'GetPointAddress',
            sub {
                return {
                    PointAddressType => {
                        Id   => 99,
                        Name => 'Air force',
                    },

                    Id        => '12345',
                    SharedRef => { Value => { anyType => '1000000002' } },
                    PointType => 'PointAddress',
                    Coordinates => {
                        GeoPoint =>
                            { Latitude => 51.408688, Longitude => -0.304465 }
                    },
                    Description => '2 Example Street, Kingston, KT1 1AA',
                };
            }
        );

        $mech->get_ok('/waste');
        $mech->content_contains('Book a bulky waste collection');
        $mech->submit_form_ok( { with_fields => { postcode => 'KT1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );

        $mech->content_lacks('Bulky waste');
    };

    subtest 'Ineligible farm' => sub {
        $echo->mock( 'GetPointAddress', sub {
            return {
                PointAddressType => { Id => 7, Name => 'Farm' },
                Id => '12345',
                Description => '2 Example Street, Kingston, KT1 1AA',
            };
        });
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Bulky waste');
    };

    subtest 'Ineligible property as no services (new build)' => sub {
    $echo->mock( 'GetServiceUnitsForObject', sub { [] } );
    $echo->mock(
        'GetPointAddress',
            sub {
                return {
                    PointAddressType => {
                        Id   => 1,
                        Name => 'Detached',
                    },

                    Id        => '12345',
                    SharedRef => { Value => { anyType => '1000000002' } },
                    PointType => 'PointAddress',
                    Coordinates => {
                        GeoPoint =>
                            { Latitude => 51.408688, Longitude => -0.304465 }
                    },
                    Description => '2 Example Street, Kingston, KT1 1AA',
                };
            }
        );
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'KT1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );
        $mech->content_lacks('Bulky waste');
        $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 2238}] } );
    };

    subtest 'Eligible property' => sub {
        $echo->mock(
            'GetPointAddress',
            sub {
                return {
                    PointAddressType => {
                        Id   => 1,
                        Name => 'Detached',
                    },

                    Id        => '12345',
                    SharedRef => { Value => { anyType => '1000000002' } },
                    PointType => 'PointAddress',
                    Coordinates => {
                        GeoPoint =>
                            { Latitude => 51.408688, Longitude => -0.304465 }
                    },
                    Description => '2 Example Street, Kingston, KT1 1AA',
                };
            }
        );

        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'KT1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );

        $mech->content_contains('Bulky waste');
        $mech->submit_form_ok; # 'Book Collection'
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
        return {
            transactionState => 'COMPLETE',
            paymentResult => {
                status => 'SUCCESS',
                paymentDetails => {
                    paymentHeader => {
                        uniqueTranId => 54321
                    }
                }
            }
        };
    });

    my $report;
    subtest 'Bulky goods collection booking' => sub {
        $mech->get_ok('/waste/12345/bulky');

        subtest 'Intro page' => sub {
            $mech->content_contains('Book bulky items collection');
            $mech->content_contains('Before you start your booking');
            $mech->content_contains('you may wish to add pictures');
            $mech->content_contains('You can request up to <strong>eight items per collection');
            $mech->content_contains('The price you pay depends how many items you would like collected:');
            $mech->content_contains('1–4 items = £40.00');
            $mech->content_contains('5–8 items = £61.00');
            $mech->content_contains('Bookings are final and non refundable');
            $mech->submit_form_ok;
        };
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email, phone => '44 07 111 111 111' }});
        $mech->content_contains('Collections take place any time from 6:30am to 4:30pm.');
        $mech->content_contains('placed outside before 6:30am on the collection day.');
        $mech->content_contains('1 July');
        $mech->content_contains('8 July');
        $mech->content_contains('2023-07-01T00:00:00;reserve1==::reserve4==;2023-06-25T10:10:00');
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2023-07-01T00:00:00;reserve1==::reserve4==;2023-06-25T10:10:00' } }
        );
        $mech->content_contains('Select the items that you need us to collect using the');
        $mech->content_contains('You can book the collection of up to eight items');

        subtest 'higher band try' => sub {
            $mech->submit_form_ok(
                {
                    form_number => 1,
                    fields => {
                        'item_1' => 'BBQ',
                        'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                        'item_2' => 'Bicycle',
                        'item_3' => 'Bath',
                        'item_4' => 'Bath',
                        'item_5' => 'Bath',
                    },
                },
            );
            $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
            $mech->content_contains('5 items requested for collection');
            $mech->content_contains('£61.00');
            $mech->back;
            $mech->back;
        };

        $mech->content_contains('You can also add an optional note');
        $mech->submit_form_ok(
            {
                form_number => 1,
                fields => {
                    'item_1' => 'BBQ',
                    'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                    'item_2' => 'Bicycle',
                    'item_3' => 'Bath',
                },
            },
        );
        $mech->content_contains('Items must be out for collection by 6:30am on the collection day.');
        $mech->submit_form_ok({ with_fields => { location => '' } }, 'Will error with a blank location');
        $mech->submit_form_ok({ with_fields => { location => ( 'a' x 251 ) } });
        $mech->content_contains('tandc', 'No max location length');
        $mech->back;
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });

        sub test_summary {
            $mech->content_contains('Booking Summary');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_lacks('No image of the location has been attached.');
            $mech->content_contains('£40.00');
            $mech->content_contains("<dd>Saturday 01 July 2023</dd>");
            $mech->content_contains("on or before Saturday 01 July 2023");
            $mech->content_contains('Bob Marge', 'name shown');
            $mech->content_contains('44 07 111 111 111', 'phone shown');
        }

        subtest 'Summary page' => \&test_summary;

        subtest 'Chosen date expired, no matching slot available' => sub {
            set_fixed_time('2023-06-25T10:10:01');
            $echo->redefine( call => sub {
                is $_[1], 'ReserveAvailableSlotsForEvent';
                is $_[2], 'event';
                is $_[3]->{EventTypeId}, 3130;
                is $_[3]->{ServiceId}, 986;
                is $_[3]->{Data}[0]{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value}, 1842;
                # Dig down to the property ID
                is $_[3]->{EventObjects}{EventObject}{ObjectRef}{Value}[0]{'msArray:anyType'}->value, 12345;
                return {
                    ReservedTaskInfo => [
                        {
                            Description => 'TaskType_1234',
                            ReservedSlots => {
                                ReservedSlot => [
                                    {
                                        StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                                        EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                                        Expiry => { DateTime => '2023-06-25T10:20:00Z' },
                                        Reference => 'reserve7a==',
                                    },
                                ]
                            }
                        },
                        {
                            Description => 'TaskType_5678',
                            ReservedSlots => {
                                ReservedSlot => [
                                    {
                                        StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                                        EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                                        Expiry => { DateTime => '2023-06-25T10:20:00Z' },
                                        Reference => 'reserve7b==',
                                    },
                                ]
                            }
                        }
                    ]
                };
            });

            # Submit summary form
            $mech->submit_form_ok( { with_fields => { tandc => 1 } } );
            $mech->content_contains(
                'Unfortunately, the slot you originally chose has become fully booked. Please select another date.',
                'Redirects to slot selection page',
            );

            $mech->submit_form_ok(
                {   with_fields => {
                        chosen_date =>
                            '2023-07-08T00:00:00;reserve7a==::reserve7b==;2023-06-25T10:20:00'
                    }
                },
                'submit new slot selection',
            );

            subtest 'submit items & location again' => sub {
                $mech->submit_form_ok;
                $mech->submit_form_ok;
            };

            subtest 'date info has changed on summary page' => sub {
                $mech->content_contains("<dd>Saturday 08 July 2023</dd>");
                $mech->content_contains("on or before Saturday 08 July 2023");
            };
        };

        subtest 'Chosen date expired, but matching slot is available' => sub {
            set_fixed_time('2023-06-25T10:20:01');
            $echo->redefine( call => sub {
                is $_[1], 'ReserveAvailableSlotsForEvent';
                is $_[2], 'event';
                is $_[3]->{EventTypeId}, 3130;
                is $_[3]->{ServiceId}, 986;
                is $_[3]->{Data}[0]{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value}, 1842;
                # Dig down to the property ID
                is $_[3]->{EventObjects}{EventObject}{ObjectRef}{Value}[0]{'msArray:anyType'}->value, 12345;
                return {
                    ReservedTaskInfo => [
                        {
                            Description => 'TaskType_1234',
                            ReservedSlots => {
                                ReservedSlot => [
                                    {
                                        StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                                        EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                                        Expiry => { DateTime => '2023-06-25T10:30:00Z' },
                                        Reference => 'reserve8a==',
                                    },
                                ]
                            }
                        },
                        {
                            Description => 'TaskType_5678',
                            ReservedSlots => {
                                ReservedSlot => [
                                    {
                                        StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                                        EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                                        Expiry => { DateTime => '2023-06-25T10:30:00Z' },
                                        Reference => 'reserve8b==',
                                    },
                                ]
                            }
                        }
                    ]
                };
            });

            $mech->waste_submit_check({ with_fields => { tandc => 1 } });
        };

        my $catch_email;
        subtest 'Payment page' => sub {
            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky goods collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->state, 'confirmed', 'report confirmed';

            is $sent_params->{items}[0]{amount}, 4000, 'correct amount used';
            is $sent_params->{items}[0]{reference}, 'customer-ref-bulky';
            is $sent_params->{items}[0]{lineId}, 'RBK-BULKY-' . $new_report->id . '-' . $new_report->name;

            $mech->log_in_ok($new_report->user->email);
            $mech->get_ok("/waste/12345");
            $mech->content_lacks('Items to be collected');
            $mech->log_out_ok;

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';
            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1); # Only email is 'email' to council
            $mech->clear_emails_ok;
            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            is $sent_params->{scpReference}, 12345, 'correct scpReference sent';
            FixMyStreet::Script::Reports::send();
            $catch_email = $mech->get_email;
            $mech->clear_emails_ok;
            $new_report->discard_changes;
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

            my $update = $new_report->comments->first;
            is $update->state, 'confirmed';
            is $update->text, 'Payment confirmed, reference 54321, amount £40.00';
            FixMyStreet::Script::Alerts::send_updates();
            $mech->email_count_is(0);
        };

        subtest 'Bulky goods email confirmation' => sub {
            my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
            my $today = $report->confirmed->strftime('%A %d %B %Y');
            my $id = $report->id;
            is $catch_email->header('Subject'), "Your bulky waste collection - reference RBK-$id";
            my $confirmation_email_txt = $mech->get_text_body_from_email($catch_email);
            my $confirmation_email_html = $mech->get_html_body_from_email($catch_email);
            like $confirmation_email_txt, qr/Reference: RBK-$id/, 'Includes reference number';
            like $confirmation_email_txt, qr/Items to be collected:/, 'Includes header for items';
            like $confirmation_email_txt, qr/- BBQ/, 'Includes item 1';
            like $confirmation_email_txt, qr/- Bicycle/, 'Includes item 2';
            like $confirmation_email_txt, qr/- Bath/, 'Includes item 3';
            like $confirmation_email_txt, qr/Total cost: £40.00/, 'Includes price';
            like $confirmation_email_txt, qr/Address: 2 Example Street, Kingston, KT1 1AA/, 'Includes collection address';
            like $confirmation_email_txt, qr/Collection date: Saturday 08 July 2023/, 'Includes collection date';
            like $confirmation_email_txt, qr#http://kingston.example.org/waste/12345/bulky/cancel#, 'Includes cancellation link';
            like $confirmation_email_txt, qr/Please check you have read the terms and conditions tandc_link/, 'Includes terms and conditions';
            like $confirmation_email_txt, qr/Make sure your items are out by 6:30am on collection day/, 'Includes information about collection';
            like $confirmation_email_html, qr#Reference: <strong>RBK-$id</strong>#, 'Includes reference number (html mail)';
            like $confirmation_email_html, qr/Items to be collected:/, 'Includes header for items (html mail)';
            like $confirmation_email_html, qr/BBQ/, 'Includes item 1 (html mail)';
            like $confirmation_email_html, qr/Bicycle/, 'Includes item 2 (html mail)';
            like $confirmation_email_html, qr/Bath/, 'Includes item 3 (html mail)';
            like $confirmation_email_html, qr/Total cost: £40.00/, 'Includes price (html mail)';
            like $confirmation_email_html, qr/Address: 2 Example Street, Kingston, KT1 1AA/, 'Includes collection address (html mail)';
            like $confirmation_email_html, qr/Collection date: Saturday 08 July 2023/, 'Includes collection date (html mail)';
            like $confirmation_email_html, qr#http://kingston.example.org/waste/12345/bulky/cancel#, 'Includes cancellation link (html mail)';
            like $confirmation_email_html, qr/a href="tandc_link"/, 'Includes terms and conditions (html mail)';
            like $confirmation_email_html, qr/Make sure your items are out by 6:30am on collection day/, 'Includes information about collection (html mail)';
        };

        subtest 'Confirmation page' => sub {
            $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
            $mech->content_contains('Bulky collection booking confirmed');
            $mech->content_contains('Our contractor will collect the items you have requested on Saturday 08 July 2023.');
            $mech->content_contains('Item collection starts from 6:30am.&nbsp;Please have your items ready for collection.');
            $mech->content_contains('We have emailed confirmation of your booking to pkg-tappcontrollerwaste_kands_bulkyt-bob@example.org.');
            $mech->content_contains('If you need to contact us about your booking please use the reference:&nbsp;RBK-' . $report->id);
            $mech->content_contains('Card payment reference: 54321');
            $mech->content_contains('Return to property details');
            is $report->detail, "Address: 2 Example Street, Kingston, KT1 1AA";
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky goods collection';
            is $report->get_extra_field_value('uprn'), 1000000002;
            is $report->get_extra_field_value('Collection_Date_-_Bulky_Items'), '2023-07-08T00:00:00';
            is $report->get_extra_field_value('TEM_-_Bulky_Collection_Item'), '3::85::83';
            is $report->get_extra_field_value('property_id'), '12345';
            is $report->get_extra_field_value('First_Date_Offered_-_Bulky'), '08/07/2023';
            like $report->get_extra_field_value('GUID'), qr/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/;
            is $report->get_extra_field_value('reservation'), 'reserve8a==::reserve8b==';
            is $report->photo, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';

            is $report->name, 'Bob Marge', 'correct name on report';
            is $report->get_extra_metadata('phone'), '44 07 111 111 111',
                'correct phone on report';
            is $report->user->name, 'Original Name',
                'name on report user unchanged';
            is $report->user->phone, undef, 'no phone on report user';
            is $report->user->email, $user->email,
                'correct email on report user';
        };
    };

    # Collection date: 2023-07-08T00:00:00
    # Time/date that is within the cancellation window:
    my $good_date = '2023-07-02T05:44:59Z'; # 06:44:59 UK time

    subtest 'Bulky goods collection viewing' => sub {
        subtest 'View own booking' => sub {
            $mech->log_in_ok($report->user->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('2 Example Street, Kingston, KT1 1AA');
            $mech->content_lacks('Please read carefully all the details');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('£40.00');
            $mech->content_contains('8 July');
            $mech->content_lacks('Request a bulky waste collection');
            $mech->content_contains('Your bulky waste collection');
            $mech->content_contains('Return to property details');
            $mech->content_contains('Bob Marge', 'name shown');
            $mech->content_contains('44 07 111 111 111', 'phone shown');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');

            set_fixed_time($good_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("You can cancel this booking any time before");
            $mech->content_contains("on or before Saturday 08 July 2023");

            # Presence of external_id in report implies we have sent request
            # to Echo
            $mech->content_lacks('/waste/12345/bulky/cancel');
            $mech->content_lacks('Cancel this booking');
            $report->external_id('Echo-123');
            $report->update;
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains('/waste/12345/bulky/cancel');
            $mech->content_contains('Cancel this booking');
        };

        subtest "Can follow link to booking from bin days page" => sub {
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { text_regex => qr/Check collection details/i, }, "follow 'Check collection...' link" );
            is $mech->uri->path, '/report/' . $report->id , 'Redirected to waste base page';
        };
    };

    subtest 'Bulky goods email reminders' => sub {
        set_fixed_time('2023-07-05T05:44:59Z');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        my $cobrand = $body->get_cobrand_handler;
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
        like $reminder_email_txt, qr/Address: 2 Example Street, Kingston, KT1 1AA/, 'Includes collection address';
        like $reminder_email_txt, qr/on Saturday 08 July 2023/, 'Includes collection date';
        like $reminder_email_txt, qr#http://kingston.example.org/waste/12345/bulky/cancel#, 'Includes cancellation link';
        like $reminder_email_html, qr/Thank you for booking a bulky waste collection with Kingston upon Thames Council/, 'Includes Kingston greeting (html mail)';
        like $reminder_email_html, qr/Address: 2 Example Street, Kingston, KT1 1AA/, 'Includes collection address (html mail)';
        like $reminder_email_html, qr/on Saturday 08 July 2023/, 'Includes collection date (html mail)';
        like $reminder_email_html, qr#http://kingston.example.org/waste/12345/bulky/cancel#, 'Includes cancellation link (html mail)';
        $mech->clear_emails_ok;
    };

    subtest 'Email when update fails to be sent to Echo' => sub {
        $report->unset_extra_metadata('payment_reference');
        $report->update({ created => '2023-06-25T00:00:00' });

        my $cobrand = $body->get_cobrand_handler;
        $cobrand->send_bulky_payment_echo_update_failed;
        ok $mech->email_count_is(0),
            'No email if report does not have a payment_reference';

        $report->set_extra_metadata( payment_reference => 123 );
        $report->update;
        my $ex_id_comment
            = $mech->create_comment_for_problem( $report, $user, 'User',
            'Payment confirmed, reference', undef, 'confirmed', undef,
            { external_id => 234 });
        $cobrand->send_bulky_payment_echo_update_failed;
        ok $mech->email_count_is(0),
            'No email if report has comment with external_id';

        $ex_id_comment->delete;
        $report->discard_changes;
        $report->unset_extra_metadata('echo_update_sent');
        $report->update;
        $cobrand->send_bulky_payment_echo_update_failed;
        my $email = $mech->get_email;
        like $email->as_string, qr/Collection date: Saturday 08 July 2023/;
        like $email->as_string, qr/40\.00/;

        $mech->clear_emails_ok;

        $report->discard_changes;
        is $report->get_extra_metadata('echo_update_failure_email_sent'),
            1, 'flag set when email sent';
        $cobrand->send_bulky_payment_echo_update_failed;
        ok $mech->email_count_is(0),
            'No email if email previously sent';

        $mech->clear_emails_ok;
    };

    subtest 'Cancellation' => sub {
        my $base_path = '/waste/12345';
        $mech->get_ok($base_path);
        $mech->content_contains('Cancel booking');
        $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
        $mech->content_contains('I acknowledge that the collection fee is non-refundable');
        $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
        $mech->content_contains('Your booking has been cancelled');
        $mech->follow_link_ok( { text => 'Return to property details' } );
        is $mech->uri->path, $base_path, 'Returned to bin days';
        $mech->content_lacks('Cancel booking');

        $report->discard_changes;
        is $report->state, 'cancelled', 'Original report cancelled';
        like $report->detail, qr/Cancelled at user request/, 'Original report detail field updated';

        subtest 'Viewing original report summary after cancellation' => sub {
            my $id   = $report->id;
            $mech->get_ok("/report/$id");
            $mech->content_contains('This collection has been cancelled');
            $mech->content_lacks("You can cancel this booking up to");
            $mech->content_lacks('Cancel this booking');
        };
    };

    subtest 'Missed collections' => sub {
        $report->update({ state => 'fixed - council', external_id => 'a-guid' });

        # Fixed date still set to 5th July
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a bulky waste collection as missed');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Bulky waste collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 3130,
            ResolvedDate => { DateTime => '2023-07-02T00:00:00Z' },
            ResolutionCodeId => 232,
            EventStateId => 12400,
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a bulky waste collection as missed', 'Too long ago');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Bulky waste collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 3130,
            ResolvedDate => { DateTime => '2023-07-05T00:00:00Z' },
            ResolutionCodeId => 232,
            EventStateId => 12400,
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a bulky waste collection as missed', 'In time, normal completion');
        $mech->submit_form_ok({ form_number => 1 }, "Follow link for reporting a missed bulky collection");
        $mech->content_contains('Bulky waste collection');
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ with_fields => { extra_detail => "They left the mattress" } });
        $mech->submit_form_ok({ form_number => 1 });
        $mech->content_contains('Submit missed bulky collection');
        $mech->submit_form_ok({ form_number => 3 });

        my $missed = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $missed->get_extra_field_value('Exact_Location'), 'in the middle of the drive';
        is $missed->title, 'Report missed bulky collection';
        is $missed->get_extra_field_value('Original_Event_ID'), 'a-guid';
        is $missed->get_extra_field_value('Notes'), 'They left the mattress';

        $missed->update({ external_id => 'guid' });

        $echo->mock( 'GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 3130,
            ResolvedDate => { DateTime => '2023-07-05T00:00:00Z' },
            ResolutionCodeId => 379,
            EventStateId => 12401,
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A missed collection cannot be reported', 'Not completed');
        $mech->content_contains('Item not as described');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Bulky waste collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 3130,
            ResolvedDate => { DateTime => '2023-07-05T00:00:00Z' },
            ResolutionCodeId => 100,
            EventStateId => 12401,
        }, {
            EventTypeId => 3145,
            EventStateId => 0,
            ServiceId => 986,
            Guid => 'guid',
            EventDate => { DateTime => '2023-07-05T00:00:00Z' },
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A bulky waste collection has been reported as missed');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Bulky waste collection');
        $echo->mock( 'GetEventsForObject', sub { [] } );
    };

    subtest 'Bulky goods cheque payment by contact centre' => sub {
        $mech->log_in_ok($contact_centre_user->email);
        $mech->get_ok('/waste/12345/bulky');
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2023-07-08T00:00:00;reserve4==;2023-06-25T10:20:00' } }
        );
        $mech->submit_form_ok({
            form_number => 1,
            fields => {
                'item_1' => 'BBQ',
                'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                'item_2' => 'Bicycle',
                'item_3' => 'Bath',
                'item_4' => 'Bath',
                'item_5' => 'Bath',
            },
        });
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->content_contains('How do you want to pay');
        $mech->content_contains('Debit or Credit Card');
        $mech->content_contains('Cheque payment');
        $mech->content_contains('Payment reference');
        $mech->submit_form_ok({ with_fields => { tandc => 1, payment_method => 'cheque' } });
        $mech->content_contains('Payment reference field is required');
        $mech->submit_form_ok({ with_fields => { tandc => 1, payment_method => 'cheque', cheque_reference => '12345' } });
        $mech->content_contains('Bulky collection booking confirmed');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_metadata('chequeReference'), 12345;
        is $report->get_extra_field_value('payment_method'), 'cheque';
    }
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => ['sutton'],
    COBRAND_FEATURES => {
        waste => { sutton => 1 },
        waste_features => {
            sutton => {
                bulky_enabled => 1,
                bulky_missed => 1,
                bulky_tandc_link => 'tandc_link',
                echo_update_failure_email => 'fail@example.com',
            },
        },
        echo => {
            sutton => {
                bulky_address_types => [ 1, 7 ],
                bulky_service_id => 960,
                bulky_event_type_id => 3130,
                url => 'http://example.org',
                nlpg => 'https://example.com/%s',
            },
        },
        payment_gateway => {
            sutton => {
                cc_url => 'http://example.com',
                hmac => '1234',
                hmac_id => '1234',
                company_name => 'lbs',
                customer_ref => 'customer-ref',
                bulky_customer_ref => 'customer-ref-bulky',
            },
        },
    }
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock( 'GetTasks',                 sub { [] } );
    $echo->mock( 'GetEventsForObject',       sub { [] } );

    $echo->mock(
        'FindPoints',
        sub {
            [   {   Description => '2/3 Example Street, Sutton, SM2 5HF',
                    Id          => '12345',
                    SharedRef   => { Value => { anyType => 1000000002 } }
                },
            ]
        }
    );
    $echo->mock( 'CancelReservedSlotsForEvent', sub {
        my (undef, $guid) = @_;
        ok $guid, 'non-nil GUID passed to CancelReservedSlotsForEvent';
    } );
    $echo->redefine( call => sub {
        is $_[1], 'ReserveAvailableSlotsForEvent';
        is $_[2], 'event';
        is $_[3]->{EventTypeId}, 3130;
        is $_[3]->{ServiceId}, 960;
        is $_[3]->{Data}[0]{ExtensibleDatum}{ChildData}{ExtensibleDatum}[0]{Value}, 1842;
        # Dig down to the property ID
        my $property = $_[3]->{EventObjects}{EventObject}{ObjectRef}{Value}[0]{'msArray:anyType'}->value;
        like $property, qr/1234[56]/;
        if ($property == 12345) {
            is $_[5]{From}{'dataContract:DateTime'}, '2023-07-07T00:00:00Z';
        } elsif ($property == 12346) {
            is $_[5]{From}{'dataContract:DateTime'}, '2023-07-08T00:00:00Z';
        }
        return {
            ReservedTaskInfo => [
                {
                    Description => 'TaskType_1234',
                    ReservedSlots => {
                        ReservedSlot => [
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
                        ]
                    }
                },
                {
                    Description => 'TaskType_5678',
                    ReservedSlots => {
                        ReservedSlot => [
                            {
                                StartDate => { DateTime => '2023-07-01T00:00:00Z' },
                                EndDate => { DateTime => '2023-07-02T00:00:00Z' },
                                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                                Reference => 'reserve4==',
                            }, {
                                StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                                EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                                Reference => 'reserve5==',
                            }, {
                                StartDate => { DateTime => '2023-07-22T00:00:00Z' },
                                EndDate => { DateTime => '2023-07-16T00:00:00Z' },
                                Expiry => { DateTime => '2023-06-25T10:10:00Z' },
                                Reference => 'reserve6==',
                            },
                        ]
                    }
                }
            ]
        };
    });

    $echo->mock('GetPointAddress', sub {
        my ($self, $id) = @_;
        return {
            Id => $id,
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House', Id => 1 },
            Coordinates => { GeoPoint => { Latitude => 51.354679, Longitude => -0.183895 } },
            Description => '2/3 Example Street, Sutton, SM2 5HF',
        };
    });

    $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 2238}] } );

    subtest 'No bulky service, no option' => sub {
        $mech->get_ok('/waste/12346/');
        $mech->content_lacks('Bulky Waste');
    };

    $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 2238}, {'ServiceId' => 960}] } );

    subtest 'Sutton specific Bulky Waste text' => sub {
        $mech->get_ok('/waste/12346/');
        $mech->content_contains('Bulky Waste');
    };

    subtest 'Sutton dates window after 11pm does not include the next day' => sub {
        set_fixed_time('2023-07-06T23:00:00Z');
        $mech->log_in_ok($sutton_staff->email);
        $mech->get_ok('/waste/12346/bulky');
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { name => 'Next Day', email => $user->email }});
    };

    subtest 'Sutton dates window includes the next day' => sub {
        set_fixed_time('2023-07-06T10:00:00Z');
        $mech->log_in_ok($sutton_staff->email);
        $mech->get_ok('/waste/12345/bulky');
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { name => 'Next Day', email => $user->email }});
    };

    my $report;
    subtest 'Sutton staff paye payment sends user confirmation email' => sub {
        FixMyStreet::Script::Alerts::send_updates();
        $mech->clear_emails_ok;
        $mech->log_in_ok($sutton_staff->email);
        $mech->get_ok('/waste/12345/bulky');
        $mech->submit_form_ok;
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
        $mech->content_contains('2023-07-08T00:00:00;reserve2==::reserve5==;2023-06-25T10:10:00');
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2023-07-08T00:00:00;reserve2==::reserve5==;2023-06-25T10:10:00' } }
        );
        $mech->content_lacks('You can also add an optional note');
        $mech->submit_form_ok(
            {
                form_number => 1,
                fields => {
                    'item_1' => 'BBQ',
                    'item_notes_1' => 'BBQ note',
                    'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                    'item_2' => 'Bicycle',
                    'item_notes_2' => 'Bike note',
                    'item_3' => 'Bath',
                    'item_notes_3' => 'Bath note',
                },
            },
        );
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });
        $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_field_value('payment_method'), 'csc';
        is $report->get_extra_field_value('reservation'), 'reserve2==::reserve5==';
        $mech->submit_form_ok({ with_fields => { payenet_code => '54321' } });
        my $email = $mech->get_email;
        like $email->header('Subject'), qr/Your bulky waste collection - reference LBS/, "Confirmation booking email sent after staff payment process";
    };

    subtest 'Escalations of missed collections' => sub {
        # Update Kingston missed report above to be Sutton
        my $missed = FixMyStreet::DB->resultset("Problem")->search({ category => 'Report missed collection' })->order_by('-id')->first;
        $missed->update_extra_field({ name => 'Original_Event_ID', value => 'booking-guid' });
        $missed->update({ external_id => 'missed-guid', cobrand => 'sutton', bodies_str => $sutton->id });

        # Update the bulky collection to have been done (at right time)
        $report->update_extra_field({ name => 'Collection_Date_-_Bulky_Items', value => '2025-04-08T00:00:00' });
        $report->set_extra_metadata(payment_reference => 'payref');
        $report->update({ external_id => 'booking-guid', state => 'fixed - council' });

        my $escalation;
        subtest 'Open missed collection' => sub {
            $echo->mock('GetEventsForObject', sub { [ {
                Id => '8004',
                ClientReference => 'LBS-123',
                Guid => 'booking-guid',
                ServiceId => 960, # Bulky
                EventTypeId => 3130, # Bulky collection
                EventStateId => 19184, # Completed
                EventDate => { DateTime => '2025-04-01T00:00:00Z' },
                ResolvedDate => { DateTime => '2025-04-08T00:00:00Z' },
                ResolutionCodeId => 232, # Completed on Scheduled Day (dunno if used, doesn't matter)
            }, {
                Id => '315530',
                ClientReference => 'LBS-456',
                Guid => 'missed-guid',
                ServiceId => 960, # Bulky
                EventTypeId => 3145, # Missed collection
                EventStateId => 19240, # Allocated to Crew
                EventDate => { DateTime => "2025-04-08T17:00:00Z" },
            } ] });

            set_fixed_time('2025-04-08T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');;

            set_fixed_time('2025-04-10T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok({ text => 'please report the problem here' });

            subtest 'actually make the report' => sub {
                $mech->submit_form_ok( { with_fields => { name => 'Joe Schmoe', email => 'schmoe@example.org' } });
                $mech->submit_form_ok( { with_fields => { submit => '1' } });
                $mech->content_contains('Your enquiry has been submitted');
                $mech->content_contains('Return to property details');
                $mech->content_contains('/waste/12345"');
                $escalation = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
                is $escalation->category, 'Complaint against time', "Correct category";
                is $escalation->detail, "2/3 Example Street, Sutton, SM2 5HF", "Details of report contain information about problem";
                is $escalation->user->email, 'schmoe@example.org', 'User details added to report';
                is $escalation->name, 'Joe Schmoe', 'User details added to report';
                is $escalation->get_extra_field_value('Notes'), 'Originally Echo Event #315530';
                is $escalation->get_extra_field_value('missed_guid'), 'missed-guid';
                is $escalation->get_extra_field_value('original_ref'), 'LBS-456';
            };

            set_fixed_time('2025-04-12T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_contains('please report the problem here');
            set_fixed_time('2025-04-14T17:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_contains('please report the problem here');
            set_fixed_time('2025-04-14T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_lacks('please report the problem here');
        };

        $escalation->update({ external_id => 'escalation-guid' });

        subtest 'Existing escalation event' => sub {
            # Now mock there is an existing escalation
            $echo->mock('GetEventsForObject', sub { [ {
                Id => '8004',
                Guid => 'booking-guid',
                ServiceId => 960, # Bulky
                EventTypeId => 3130, # Bulky collection
                EventStateId => 19184, # Completed
                EventDate => { DateTime => '2025-04-01T00:00:00Z' },
                ResolvedDate => { DateTime => '2025-04-08T00:00:00Z' },
                ResolutionCodeId => 232, # Completed on Scheduled Day (dunno if used, doesn't matter)
            }, {
                Id => '315530',
                Guid => 'missed-guid',
                ServiceId => 960, # Bulky
                EventTypeId => 3145, # Missed collection
                EventStateId => 19240, # Allocated to Crew
                EventDate => { DateTime => "2025-04-08T17:00:00Z" },
            }, {
                Id => '112112321',
                Guid => 'escalation-guid',
                EventTypeId => 3134, # Complaint against time
                EventStateId => 0,
                ServiceId => 960, # Bulky
                EventDate => { DateTime => "2025-04-11T19:00:00Z" },
            } ] });

            set_fixed_time('2025-04-12T19:00:00Z');
            $mech->get_ok('/waste/12345');
            $mech->content_contains('Thank you for reporting an issue with this collection; we are investigating.');
            $mech->content_lacks('please report the problem here');
        };

        $echo->mock('GetEventsForObject', sub { [] }); # reset
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
        base_price => '6100',
        band1_price => '4000',
        band1_max => 4,
        items_per_collection_max => 8,
        per_item_costs => 0,
        show_location_page => 'users',
        show_individual_notes => 1,
        item_list => [
            { bartec_id => '83', name => 'Bath' },
            { bartec_id => '84', name => 'Bathroom Cabinet /Shower Screen' },
            { bartec_id => '85', name => 'Bicycle' },
            { bartec_id => '3', name => 'BBQ' },
            { bartec_id => '6', name => 'Bookcase, Shelving Unit' },
        ],
    },
);
$body->update;
}

sub create_bulky_contact {
    my ($body) = @_;
    my $params = { category => 'Bulky collection', email => '1636@test.com' };
    my @extra = (
        { code => 'payment' },
        { code => 'payment_method' },
        { code => 'Collection_Date_-_Bulky_Items' },
        { code => 'TEM_-_Bulky_Collection_Item' },
        { code => 'TEM_-_Bulky_Collection_Description' },
        { code => 'Exact_Location' },
        { code => 'GUID' },
        { code => 'reservation' },
        { code => 'First_Date_Offered_-_Bulky' },
    );
    create_contact($body, $params, @extra);
}

sub create_contact {
    my ($body, $params, @extra) = @_;

    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste'], extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}
