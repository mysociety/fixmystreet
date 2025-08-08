use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use CGI::Simple;
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

my $body = $mech->create_body_ok( 2500, 'Merton Council',
    { comment_user => $body_user, cobrand => 'merton' } );

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
$contact_centre_user->user_body_permissions->create({ body => $body, permission_type => 'report_mark_private' });

for ($body) {
    add_extra_metadata($_);
    create_contact($_);
}

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'merton',
    COBRAND_FEATURES => {
        waste => { merton => 1 },
        waste_features => {
            merton => {
                bulky_enabled => 1,
                bulky_amend_enabled => 'staff',
                bulky_cancel_enabled => 'staff',
                bulky_missed => 1,
                bulky_tandc_link => 'tandc_link',
                echo_update_failure_email => 'fail@example.com',
            },
        },
        echo => {
            merton => {
                bulky_address_types => [ 1, 7 ],
                bulky_service_id => 413,
                bulky_event_type_id => 1636,
                url => 'http://example.org',
                nlpg => 'https://example.com/%s',
                open311_endpoint => 'http://example.net/api/',
                open311_api_key => 'api_key',
            },
        },
        payment_gateway => { merton => {
            adelante => {
                username => 'un',
                password => 'pw',
                pre_shared_key => 'key',
                url => 'https://adelante.example.net/',
                channel => 'channel',
                fund_code => 32,
                cost_code => '20180282880000000000000',
            },
        } },
    },
}, sub {
    my $lwp = Test::MockModule->new('LWP::UserAgent');
    $lwp->mock(
        'get',
        sub {
            my ( $ua, $url ) = @_;
            return $lwp->original('get')->(@_) unless $url =~ /example.com/;
            my ( $uprn, $area ) = ( 1000000002, "MERTON" );
            my $j
                = '{ "results": [ { "LPI": { "UPRN": '
                . $uprn
                . ', "LOCAL_CUSTODIAN_CODE_DESCRIPTION": "'
                . $area
                . '" } } ] }';
            return HTTP::Response->new( 200, 'OK', [], $j );
        }
    );

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
            [   {   Description => '2 Example Street, Merton, KT1 1AA',
                    Id          => '12345',
                    SharedRef   => { Value => { anyType => 1000000002 } }
                },
            ]
        }
    );
    my $normal_slots = [
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
    ];
    $echo->mock('ReserveAvailableSlotsForEvent', sub {
        my ($self, $service, $event_type, $property, $guid, $start, $end) = @_;
        is $service, 413;
        is $event_type, 1636;
        is $property, 12345;
        return $normal_slots;
    });

    subtest 'Ineligible property as no bulky service' => sub {
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
                            { Latitude => 51.400975, Longitude => -0.19655 }
                    },
                    Description => '2 Example Street, Merton, KT1 1AA',
                };
            }
        );
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'KT1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );
        $mech->content_lacks('Bulky waste');
    };

    subtest 'Eligible property as has bulky service' => sub {
        $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 2238}, {'ServiceId' => 413}] } );
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
                            { Latitude => 51.400975, Longitude => -0.19655 }
                    },
                    Description => '2 Example Street, Merton, KT1 1AA',
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
    my $pay = Test::MockModule->new('Integrations::Adelante');

    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = shift;
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
        return {
            UID => '12345',
            Link => 'http://example.org/faq',
        };
    });
    my $query_return = { Status => 'Authorised', PaymentID => '54321' };
    $pay->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return $query_return;
    });

    my $report;
    subtest 'Bulky goods collection booking' => sub {
        $mech->get_ok('/waste/12345/bulky');

        subtest 'Intro page' => sub {
            $mech->content_contains('Book a bulky waste collection');
            $mech->content_contains('Before you start your booking');
            $mech->content_contains('You can request up to <strong>six items per collection');
            $mech->content_contains('The price you pay depends how many items you would like collected:');
            $mech->content_contains('1–3 items = £37.00');
            $mech->content_contains('4–6 items = £60.75');
            $mech->submit_form_ok;
        };
        $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email, phone => '44 07 111 111 111' }});
        $mech->content_contains('1 July');
        $mech->content_contains('8 July');
        $mech->submit_form_ok(
            { with_fields => { chosen_date => '2023-07-01T00:00:00;reserve1==;2023-06-25T10:10:00' } }
        );

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
            $mech->content_contains('£60.75');
            $mech->back;
            $mech->back;
        };

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
        $mech->content_contains('Items must be out for collection by 6am on the collection day.');
        $mech->submit_form_ok({ with_fields => { location => '' } }, 'Will error with a blank location');
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });

        sub test_summary {
            $mech->content_contains('Booking Summary');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('£37.00');
            $mech->content_contains("<dd>Saturday 01 July 2023</dd>");
            $mech->content_lacks("06:00 on 30 June 2023");
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

        subtest 'Chosen date expired, no matching slot available' => sub {
            set_fixed_time('2023-06-25T10:10:01');
            $echo->mock( 'ReserveAvailableSlotsForEvent', sub { [
                {
                    StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                    EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                    Expiry => { DateTime => '2023-06-25T10:20:00Z' },
                    Reference => 'reserve4==',
                },
            ] } );

            # Submit summary form
            $mech->submit_form_ok( { with_fields => { tandc => 1 } } );
            $mech->content_contains(
                'Unfortunately, the slot you originally chose has become fully booked. Please select another date.',
                'Redirects to slot selection page',
            );

            $mech->submit_form_ok(
                {   with_fields => {
                        chosen_date =>
                            '2023-07-08T00:00:00;reserve4==;2023-06-25T10:20:00'
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
            };
        };

        subtest 'Chosen date expired, but matching slot is available' => sub {
            set_fixed_time('2023-06-25T10:20:01');
            $echo->mock( 'ReserveAvailableSlotsForEvent', sub { [
                {
                    StartDate => { DateTime => '2023-07-08T00:00:00Z' },
                    EndDate => { DateTime => '2023-07-09T00:00:00Z' },
                    Expiry => { DateTime => '2023-06-25T10:30:00Z' },
                    Reference => 'reserve5==',
                },
            ] } );

            subtest 'Summary submission' => \&test_summary_submission;
        };

        my $catch_email;
        subtest 'Payment page' => sub {
            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky goods collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->state, 'confirmed', 'report confirmed';

            is $sent_params->{items}[0]{amount}, 3700, 'correct amount used';
            is $sent_params->{items}[0]{cost_code}, '20180282880000000000000';
            is $sent_params->{items}[0]{reference}, 'LBM-BWC-' . $new_report->id;

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
            is $sent_params->{reference}, 12345, 'correct scpReference sent';
            FixMyStreet::Script::Reports::send();
            $catch_email = $mech->get_email;
            $mech->clear_emails_ok;
            $new_report->discard_changes;
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

            is $new_report->comments->count, 1;
            my $update = $new_report->comments->first;
            is $update->state, 'confirmed';
            is $update->text, 'Payment confirmed, reference 54321, amount £37.00';
            is $update->get_extra_metadata('fms_extra_payments'), '54321|37.00';
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
            like $confirmation_email_txt, qr/Reference: $id/, 'Includes reference number';
            like $confirmation_email_txt, qr/Items to be collected:/, 'Includes header for items';
            like $confirmation_email_txt, qr/- BBQ/, 'Includes item 1';
            like $confirmation_email_txt, qr/- Bicycle/, 'Includes item 2';
            like $confirmation_email_txt, qr/- Bath/, 'Includes item 3';
            like $confirmation_email_txt, qr/Total cost: £37.00/, 'Includes price';
            like $confirmation_email_txt, qr/Address: 2 Example Street, Merton, KT1 1AA/, 'Includes collection address';
            like $confirmation_email_txt, qr/Collection date: Saturday 08 July 2023/, 'Includes collection date';
            unlike $confirmation_email_txt, qr#http://merton.example.org/waste/12345/bulky/cancel#, 'No cancellation link';
            like $confirmation_email_txt, qr/Please check you have read the terms and conditions tandc_link/, 'Includes terms and conditions';
            like $confirmation_email_html, qr#Reference: <strong>$id</strong>#, 'Includes reference number (html mail)';
            like $confirmation_email_html, qr/Items to be collected:/, 'Includes header for items (html mail)';
            like $confirmation_email_html, qr/BBQ/, 'Includes item 1 (html mail)';
            like $confirmation_email_html, qr/Bicycle/, 'Includes item 2 (html mail)';
            like $confirmation_email_html, qr/Bath/, 'Includes item 3 (html mail)';
            like $confirmation_email_html, qr/Total cost: £37.00/, 'Includes price (html mail)';
            like $confirmation_email_html, qr/Address: 2 Example Street, Merton, KT1 1AA/, 'Includes collection address (html mail)';
            like $confirmation_email_html, qr/Collection date: Saturday 08 July 2023/, 'Includes collection date (html mail)';
            unlike $confirmation_email_html, qr#http://merton.example.org/waste/12345/bulky/cancel#, 'No cancellation link (html mail)';
            like $confirmation_email_html, qr/a href="tandc_link"/, 'Includes terms and conditions (html mail)';
        };

        subtest 'Confirmation page' => sub {
            $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            $mech->content_contains('Bulky collection booking confirmed');
            $mech->content_contains('Our contractor will collect the items you have requested on Saturday 08 July 2023.');
            $mech->content_contains('Item collection starts from 6am.&nbsp;Please have your items ready');
            $mech->content_contains('We have emailed confirmation of your booking to pkg-tappcontrollerwaste_merton_bulkyt-bob@example.org.');
            $mech->content_contains('If you need to contact us about your booking please use the reference:&nbsp;' . $report->id);
            $mech->content_contains('Card payment reference: 54321');
            $mech->content_contains('Show upcoming bin days');
            is $report->detail, "Address: 2 Example Street, Merton, KT1 1AA";
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky goods collection';
            is $report->get_extra_field_value('uprn'), 1000000002;
            is $report->get_extra_field_value('Collection_Date'), '2023-07-08T00:00:00';
            is $report->get_extra_field_value('Bulky_Collection_Bulky_Items'), '3::85::83';
            is $report->get_extra_field_value('property_id'), '12345';
            is $report->get_extra_field_value('Customer_Selected_Date_Beyond_SLA?'), '0';
            is $report->get_extra_field_value('First_Date_Returned_to_Customer'), '08/07/2023';
            like $report->get_extra_field_value('GUID'), qr/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/;
            is $report->get_extra_field_value('reservation'), 'reserve5==';
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
            $mech->content_contains('2 Example Street, Merton, KT1 1AA');
            $mech->content_lacks('Please read carefully all the details');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('£37.00');
            $mech->content_contains('8 July');
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
            $mech->content_contains("8 July 2023");

            # Presence of external_id in report implies we have sent request
            # to Echo
            $mech->content_lacks('/waste/12345/bulky/cancel');
            $mech->content_lacks('Cancel this booking');
            $report->external_id('Echo-123');
            $report->update;
            $mech->get_ok('/report/' . $report->id);
            # Still not present, because cancelling is staff only
            $mech->content_lacks('/waste/12345/bulky/cancel');
            $mech->content_lacks('Cancel this booking');
        };

        subtest "Can follow link to booking from bin days page" => sub {
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok( { text_regex => qr/Check collection details/i, }, "follow 'Check collection...' link" );
            is $mech->uri->path, '/report/' . $report->id , 'Redirected to waste base page';
        };
    };

    subtest 'Amending' => sub {
        set_fixed_time('2023-06-28T12:13:14');
        my $base_path = '/waste/12345';

        $echo->mock('ReserveAvailableSlotsForEvent', sub {
            my ($self, $service, $event_type, $property, $guid, $start, $end) = @_;
            is $service, 413;
            is $event_type, 1636;
            is $property, 12345;
            return $normal_slots;
        });

        subtest 'Before request sent' => sub {
            $report->external_id(undef);
            $report->update;
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, $base_path, 'Amend link redirects to bin days';
        };

        subtest 'After request sent, normal user cannot' => sub {
            $report->external_id('Echo-123');
            $report->update;
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, $base_path;
        };

        subtest 'User logged out' => sub {
            $mech->log_out_ok;
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, $base_path;
        };

        subtest 'Staff user logged in' => sub {
            $mech->log_in_ok( $contact_centre_user->email );
            $mech->get_ok($base_path);
            $mech->content_contains('Amend booking');
            $mech->get_ok("/report/" . $report->id);
            $mech->content_contains("$base_path/bulky/cancel");
            $mech->content_contains('Cancel this booking');
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            is $mech->uri->path, "$base_path/bulky/amend/" . $report->id;
        };

        # Only staff so stay logged in as staff
        $mech->get_ok("$base_path/bulky/amend/" . $report->id);
        $mech->content_contains("Before you amend your booking");
        $mech->submit_form_ok;

        subtest 'Do not change anything' => sub {
            $mech->content_contains('Choose date for collection');
            $mech->content_contains('Available dates');
            $mech->content_contains('8 July'); # Existing date should always be there
            $mech->content_contains('1 July');
            $mech->content_contains('15 July');
            $mech->submit_form_ok; # Date page
            $mech->content_contains('Add items for collection');
            $mech->content_like(
                qr/<option value="Bath".*>Bath<\/option>/);
            $mech->submit_form_ok; # Items page
            $mech->submit_form_ok; # Location page

            $mech->content_contains('Booking Summary');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_contains('Bicycle');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('£0.00 (£37.00 already paid)');
            $mech->content_contains("<dd>Saturday 08 July 2023</dd>");
            $mech->content_lacks('Cancel this booking');
            $mech->content_lacks('Show upcoming bin days');
            $mech->submit_form_ok({ with_fields => { tandc => 1 } });
            $mech->content_contains('You have not changed anything');
        };

        subtest 'Amend the date and items, not above the lower limit' => sub {
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            $mech->content_contains("Before you amend your booking");
            $mech->submit_form_ok;
            $mech->content_contains('Choose date for collection');
            $mech->content_contains('Available dates');
            $mech->content_contains('8 July'); # Existing date should always be there
            $mech->content_contains('1 July');
            $mech->content_contains('15 July');
            $mech->submit_form_ok(
                { with_fields => { chosen_date => '2023-07-01T00:00:00;reserve1==;2023-06-25T10:10:00' } }
            );
            $mech->content_contains('Add items for collection');
            $mech->content_like(
                qr/<option value="Bath".*>Bath<\/option>/);
            $mech->submit_form_ok({
                with_fields => {
                    'item_1' => 'Bath',
                    'item_photo_1_fileid' => '', # Photo removed
                    'item_2' => 'Bookcase, Shelving Unit',
                    'item_3' => '',
                },
            });
            $mech->submit_form_ok; # Location page

            $mech->content_contains('Booking Summary');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_lacks('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_lacks('BBQ');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bookcase, Shelving Unit/s);
            $mech->content_contains('2 items requested for collection');
            $mech->content_contains('£0.00 (£37.00 already paid)');
            $mech->content_contains("<dd>Saturday 01 July 2023</dd>");
            $mech->content_lacks('Cancel this booking');
            $mech->content_lacks('Show upcoming bin days');
        };

        my $new_report;
        subtest 'Confirm amendment' => sub {
            $mech->submit_form_ok({ with_fields => { tandc => 1 } });

            is $report->comments->count, 2; # Confirmation and then cancellation
            $new_report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;

            my $email = $mech->get_email;
            is $email->header('Subject'), 'Bulky waste collection service - reference ' . $new_report->id;
            $mech->clear_emails_ok;

            FixMyStreet::Script::Alerts::send_updates();
            $mech->email_count_is(0); # No cancellation update on original

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky goods collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->state, 'confirmed', 'report confirmed';
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1); # Only email is 'email' to council
            $mech->clear_emails_ok;

            is $new_report->comments->count, 1; # Payment confirmed update
            my $comment = $new_report->comments->first;
            is $comment->text, 'Payment confirmed, reference 54321, amount £0.00';
            is $comment->get_extra_metadata('fms_extra_payments'), '54321|0.00|54321|37.00';
            FixMyStreet::Script::Alerts::send_updates();
            $mech->email_count_is(0);

            $mech->content_contains('Bulky collection booking confirmed');
            $mech->content_contains('please use the reference:&nbsp;' . $new_report->id);
        };

        subtest 'Viewing original report summary after amendment' => sub {
            my $path = "/report/" . $report->id;
            $mech->get_ok($path);
            $mech->content_contains('Updates');
            $mech->content_contains('This collection has been cancelled');
            $mech->content_contains('Booking cancelled due to amendment');
            $report->discard_changes;
            is $report->state, 'cancelled';
        };

        $report = $new_report;
        subtest 'New report details' => sub {
            like $report->detail, qr/Previously submitted as/, 'Original report detail field updated';
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky goods collection';
            is $report->get_extra_field_value('uprn'), 1000000002;
            is $report->get_extra_field_value('Collection_Date'), '2023-07-01T00:00:00';
            is $report->get_extra_field_value('Bulky_Collection_Bulky_Items'), '83::6';
            is $report->get_extra_field_value('property_id'), '12345';
            is $report->get_extra_field_value('Customer_Selected_Date_Beyond_SLA?'), '0';
            is $report->get_extra_field_value('First_Date_Returned_to_Customer'), '01/07/2023';
            like $report->get_extra_field_value('GUID'), qr/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/;
            is $report->get_extra_field_value('reservation'), 'reserve1==';
            is $report->photo, undef;
        };

        subtest 'Viewing new report summary after cancellation' => sub {
            my $path = "/report/" . $report->id;
            $mech->get_ok($path);
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('Booking cancelled by customer');
            $mech->content_contains('£0.00 (£37.00 already paid)');
        };

        $report->set_extra_metadata('payment_reference' => '6789'); # So will be changed
        $report->update({ external_id => 'Echo-123' }); # So can be amended

        subtest 'Amend the date and items above the lower limit' => sub {
            $mech->get_ok("$base_path/bulky/amend/" . $report->id);
            $mech->content_contains("Before you amend your booking");
            $mech->submit_form_ok;
            $mech->content_contains('Choose date for collection');
            $mech->content_contains('Available dates');
            $mech->content_contains('1 July'); # Existing date should always be there
            $mech->content_contains('8 July');
            $mech->content_contains('15 July');
            $mech->submit_form_ok(
                { with_fields => { chosen_date => '2023-07-08T00:00:00;reserve2==;2023-06-25T10:10:00' } }
            );
            $mech->content_contains('Add items for collection');
            $mech->content_like(
                qr/<option value="Bath".*>Bath<\/option>/);
            $mech->submit_form_ok({
                form_number => 1,
                fields => {
                    'item_1' => 'Bath',
                    'item_photo_1_fileid' => '', # Photo removed
                    'item_2' => 'Bookcase, Shelving Unit',
                    'item_3' => 'Bath',
                    'item_4' => 'Bath',
                },
            });
            $mech->submit_form_ok; # Location page

            $mech->content_contains('Booking Summary');
            $mech->content_lacks('You will be redirected to the council’s card payments provider.');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_lacks('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_lacks('BBQ');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bookcase, Shelving Unit/s);
            $mech->content_contains('4 items requested for collection');
            $mech->content_contains('£23.75 (£37.00 already paid)');
            $mech->content_contains("<dd>Saturday 08 July 2023</dd>");
            $mech->content_lacks('Cancel this booking');
            $mech->content_lacks('Show upcoming bin days');
        };

        subtest 'Pay and confirm amendment' => sub {
            my $mech2 = $mech->clone;
            $mech2->submit_form_ok({ with_fields => { tandc => 1 } });
            is $mech2->res->previous->code, 302, 'payments issues a redirect';
            is $mech2->res->previous->header('Location'), "http://example.org/faq", "redirects to payment gateway";

            FixMyStreet::Script::Alerts::send_updates();
            $mech->email_count_is(0); # No cancellation update, not been confirmed yet
            $mech->clear_emails_ok;

            $report->discard_changes;
            is $report->state, 'confirmed';

            my ($token, $report_id);
            ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky goods collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'csc', 'correct payment method on report';
            is $new_report->state, 'confirmed', 'report confirmed';
            is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

            is $sent_params->{items}[0]{amount}, 2375, 'correct amount used';
            is $sent_params->{items}[0]{cost_code}, '20180282880000000000000';
            is $sent_params->{items}[0]{reference}, 'LBM-BWC-' . $new_report->id;

            $mech->clear_emails_ok;
            FixMyStreet::Script::Reports::send();
            $mech->email_count_is(1); # Only email is 'email' to council
            $mech->clear_emails_ok;

            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            is $sent_params->{reference}, 12345, 'correct scpReference sent';
            FixMyStreet::Script::Reports::send();
            my $email = $mech->get_email;
            is $email->header('Subject'), 'Bulky waste collection service - reference ' . $new_report->id;
            $mech->clear_emails_ok;
            $new_report->discard_changes;
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

            is $new_report->comments->count, 1; # Payment confirmed update
            my $update = $new_report->comments->first;
            is $update->state, 'confirmed';
            is $update->text, 'Payment confirmed, reference 54321, amount £23.75';
            is $update->get_extra_metadata('fms_extra_payments'), '54321|23.75|6789|0.00|54321|37.00';
            FixMyStreet::Script::Alerts::send_updates();
            $mech->email_count_is(0); # No cancellation update
            $mech->clear_emails_ok;

            $mech->content_contains('Bulky collection booking confirmed');
            $mech->content_contains('please use the reference:&nbsp;' . $new_report->id);
        };

        subtest 'Viewing original report summary after amendment' => sub {
            my $path = "/report/" . $report->id;
            $mech->get_ok($path);
            $mech->content_contains('Updates');
            $mech->content_contains('This collection has been cancelled');
            $mech->content_contains('Booking cancelled due to amendment');
            $mech->content_contains('£0.00 (£37.00 already paid)');
            $report->discard_changes;
            is $report->state, 'cancelled';
        };

        $report = $new_report;
        subtest 'New report details' => sub {
            like $report->detail, qr/Previously submitted as/, 'Original report detail field updated';
            is $report->category, 'Bulky collection';
            is $report->title, 'Bulky goods collection';
            is $report->get_extra_field_value('uprn'), 1000000002;
            is $report->get_extra_field_value('Collection_Date'), '2023-07-08T00:00:00';
            is $report->get_extra_field_value('Bulky_Collection_Bulky_Items'), '83::6::83::83';
            is $report->get_extra_field_value('property_id'), '12345';
            is $report->get_extra_field_value('Customer_Selected_Date_Beyond_SLA?'), '1';
            is $report->get_extra_field_value('First_Date_Returned_to_Customer'), '01/07/2023';
            like $report->get_extra_field_value('GUID'), qr/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/;
            is $report->get_extra_field_value('reservation'), 'reserve2==';
            is $report->photo, undef;
        };

        subtest 'Viewing new report summary after cancellation' => sub {
            my $path = "/report/" . $report->id;
            $mech->get_ok($path);
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('Booking cancelled by customer');
            $mech->content_contains('£23.75 (£37.00 already paid)');
        };
    };

    subtest 'Bulky goods email reminders' => sub {
        set_fixed_time('2023-07-05T05:44:59Z');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
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
        like $reminder_email_txt, qr/Address: 2 Example Street, Merton, KT1 1AA/, 'Includes collection address';
        like $reminder_email_txt, qr/Saturday 08 July 2023/, 'Includes collection date';
        unlike $reminder_email_txt, qr#http://merton.example.org/waste/12345/bulky/cancel#, 'No cancellation link';
        like $reminder_email_html, qr/Thank you for booking a bulky waste collection with Merton Council/, 'Includes Merton greeting (html mail)';
        like $reminder_email_html, qr/Address: 2 Example Street, Merton, KT1 1AA/, 'Includes collection address (html mail)';
        like $reminder_email_html, qr/Saturday 08 July 2023/, 'Includes collection date (html mail)';
        unlike $reminder_email_html, qr#http://merton.example.org/waste/12345/bulky/cancel#, 'No cancellation link (html mail)';
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
            { external_id => 234 },
            );
        $cobrand->send_bulky_payment_echo_update_failed;
        ok $mech->email_count_is(0),
            'No email if report has comment with external_id';
        $report->discard_changes;
        is $report->get_extra_metadata('echo_update_sent'), 1;

        # Mark payment confirmed update as not sent
        $ex_id_comment->update({ external_id => undef });
        $report->unset_extra_metadata('echo_update_sent');
        $report->update;
        $cobrand->send_bulky_payment_echo_update_failed;

        $ex_id_comment->discard_changes;
        is $ex_id_comment->send_state, 'skipped';

        my $email = $mech->get_email;
        like $email->as_string, qr/Collection date: Saturday 08 July 2023/;
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
        $report->update({ external_id => 'Echo-123' });
        # Collection date: 2023-07-08T00:00:00
        my $base_path = '/waste/12345';
        set_fixed_time('2023-07-07T06:00:00');
        $mech->get_ok($base_path);
        $mech->content_lacks('Cancel booking', "Can't cancel day before collection due");
        set_fixed_time($good_date);
        $mech->get_ok($base_path);
        $mech->content_contains('Cancel booking');
        $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
        $mech->submit_form_ok( { with_fields => { name => 'Test McTest', email => 'test@example.net', confirm => 1 } } );
        $mech->content_contains('Your booking has been cancelled');
        $mech->follow_link_ok( { text => 'Show upcoming bin days' } );
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

        FixMyStreet::Script::Alerts::send_updates();
        like $mech->get_text_body_from_email, qr/Booking cancelled by customer/;
        $mech->clear_emails_ok;
    };

    subtest 'Missed collections' => sub {
        $mech->log_in_ok($report->user->email);
        $echo->mock( 'GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 1636,
        } ] } );
        ok set_fixed_time('2023-07-08T13:44:59Z'), "Set current date to collection date before 6pm";
        ok $report->update({ state => 'confirmed', external_id => 'a-guid'}), 'Reopen the report from previous test which cancelled it';
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a missed bulky waste collection', "Not able to report a missed collection on day of collection before 6pm");
        ok set_fixed_time('2023-07-08T18:00:59Z'), "Set current date to collection date after 6pm";
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a missed bulky waste collection', "Can report missed collection on day of collection after 6pm");
        ok $report->update({ state => 'fixed - council', external_id => 'a-guid' }), 'Set report to fixed for next tests';
        ok set_fixed_time('2023-07-05T05:44:59Z'), 'Set current date to 5th July';
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a missed bulky waste collection');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Bulky waste collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 1636,
            ResolvedDate => { DateTime => '2023-07-02T00:00:00Z' },
            ResolutionCodeId => 232,
            EventStateId => 12400,
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a missed bulky waste collection', 'Too long ago');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Bulky waste collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 1636,
            ResolvedDate => { DateTime => '2023-07-05T00:00:00Z' },
            ResolutionCodeId => 232,
            EventStateId => 12400,
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a missed bulky waste collection', 'In time, normal completion');
        $mech->submit_form_ok({ form_number => 1 }, "Follow link for reporting a missed bulky collection");
        $mech->content_contains('Bulky waste collection');
        $mech->submit_form_ok({ form_number => 1 });
        #$mech->submit_form_ok({ with_fields => { extra_detail => "They left the mattress" } });
        $mech->submit_form_ok({ form_number => 1 });
        $mech->submit_form_ok({ form_number => 3 });

        my $missed = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $missed->get_extra_field_value('Exact_Location'), 'in the middle of the drive';
        is $missed->title, 'Report missed bulky collection';
        is $missed->get_extra_field_value('Original_Event_ID'), 'a-guid';
        #is $missed->get_extra_field_value('Notes'), 'They left the mattress';

        $missed->update({ external_id => 'guid' });

        $echo->mock( 'GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 1636,
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
            EventTypeId => 1636,
            ResolvedDate => { DateTime => '2023-07-05T00:00:00Z' },
            ResolutionCodeId => 100,
            EventStateId => 12401,
        }, {
            EventTypeId => 1571,
            ServiceId => 413,
            Guid => 'guid',
            EventDate => { DateTime => '2023-07-05T00:00:00Z' },
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A missed bulky waste collection has been reported');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Bulky waste collection');
        $echo->mock( 'GetEventsForObject', sub { [] } );
    };

    # subtest 'Bulky goods cheque payment by contact centre' => sub {
    #     $mech->log_in_ok($contact_centre_user->email);
    #     $mech->get_ok('/waste/12345/bulky');
    #     $mech->submit_form_ok;
    #     $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
    #     $mech->submit_form_ok(
    #         { with_fields => { chosen_date => '2023-07-08T00:00:00;reserve4==;2023-06-25T10:20:00' } }
    #     );
    #     $mech->submit_form_ok(
    #         {   with_fields => {
    #             'item_1' => 'BBQ',
    #             'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
    #             'item_2' => 'Bicycle',
    #             'item_3' => 'Bath',
    #             'item_4' => 'Bath',
    #             'item_5' => 'Bath',
    #             },
    #         },
    #     );
    #     $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });
    #     $mech->content_contains('How do you want to pay');
    #     $mech->content_contains('Debit or Credit Card');
    #     $mech->content_contains('Cheque payment');
    #     $mech->content_contains('Payment reference');
    #     $mech->submit_form_ok({ with_fields => { tandc => 1, payment_method => 'cheque' } });
    #     $mech->content_contains('Payment reference field is required');
    #     $mech->submit_form_ok({ with_fields => { tandc => 1, payment_method => 'cheque', cheque_reference => '12345' } });
    #     $mech->content_contains('Bulky collection booking confirmed');
    #     my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    #     is $report->get_extra_metadata('chequeReference'), 12345;
    #     is $report->get_extra_field_value('payment_method'), 'cheque';
    # }
    #

    $report->update_extra_field({ name => 'echo_id', value => 'EchoID' });
    $report->update;
    my $previous_id = $report->id;
    subtest 'Test sending of bulky report to other endpoint' => sub {
        use_ok 'FixMyStreet::Script::Merton::SendWaste';

        $echo->mock('GetEvent', sub { { Id => 1928374 } });

        my $send = FixMyStreet::Script::Merton::SendWaste->new;
        $send->send_reports; # Clear any others
        Open311->test_req_used; # Clear any use

        Open311->_inject_response('/api/requests.xml', '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>359</service_request_id></request></service_requests>');

        my $dt = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
        my ($report) = $mech->create_problems_for_body(1, $body->id, 'Bulky Report', {
            cobrand => 'merton',
            cobrand_data => 'waste',
            state => 'confirmed',
            category => 'Bulky collection',
            external_id => '123',
            dt => $dt,
        });
        $report->update_extra_field({ name => 'Bulky_Collection_Bulky_Items', value => '3::83::3' });
        $report->set_extra_metadata(previous_booking_id => $previous_id);
        $report->set_extra_metadata( item_1 => 'BBQ', item_2 => 'Bath', item_3 => 'BBQ' );
        $report->update;

        $send->send_reports;
        my $req = Open311->test_req_used;
        is $req, undef;

        $report->update({ confirmed => $dt->subtract(minutes => 20) });
        $send->send_reports;
        $req = Open311->test_req_used;
        my $cgi = CGI::Simple->new($req->content);
        is $cgi->param('api_key'), 'api_key';
        is $cgi->param('attribute[Bulky_Collection_Bulky_Items]'), 'BBQ::Bath::BBQ';
        is $cgi->param('attribute[Current_Item_Count]'), 3;
        is $cgi->param('attribute[previous_booking_id]'), $previous_id;
        is $cgi->param('attribute[previous_echo_id]'), 'EchoID';

        $report->discard_changes;
        is $report->get_extra_metadata('sent_to_crimson'), 1;
        is $report->get_extra_metadata('crimson_external_id'), "359";
        is $report->get_extra_field_value('echo_id'), "1928374";
        is $report->external_id, "123";
        $report->delete;
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
            base_price => '6075',
            band1_price => '3700',
            band1_max => 3,
            items_per_collection_max => 6,
            per_item_costs => 0,
            show_location_page => 'users',
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

sub create_contact {
    my ($body) = @_;
    my ($params, @extra) = &_contact_extra_data;

    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste'], extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

sub _contact_extra_data {
    return (
        { category => 'Bulky collection', email => '1636@test.com' },
        { code => 'payment' },
        { code => 'payment_method' },
        { code => 'Payment_Type' },
        { code => 'Collection_Date' },
        { code => 'Bulky_Collection_Bulky_Items' },
        { code => 'Bulky_Collection_Notes' },
        { code => 'Exact_Location' },
        { code => 'GUID' },
        { code => 'reservation' },
        { code => 'Customer_Selected_Date_Beyond_SLA?' },
        { code => 'First_Date_Returned_to_Customer' },
    );
}
