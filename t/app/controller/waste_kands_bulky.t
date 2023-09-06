use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use Path::Tiny;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;
my $sample_file = path(__FILE__)->parent->child("sample.jpg");

my $user = $mech->create_user_ok('bob@example.org');

my $body = $mech->create_body_ok( 2480, 'Kingston upon Thames Council',
    {}, { cobrand => 'kingston' } );
$body->set_extra_metadata(
    wasteworks_config => {
        base_price => '6100',
        band1_price => '4000',
        band1_max => 4,
        items_per_collection_max => 8,
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
    { category => 'Bulky collection', email => '1636' },
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

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'kingston',
    COBRAND_FEATURES => {
        waste => { kingston => 1 },
        waste_features => {
            kingston => {
                bulky_enabled => 1,
                bulky_tandc_link => 'tandc_link',
            },
        },
        echo => {
            kingston => {
                bulky_address_types => [ 1 ],
                bulky_service_id => 413,
                bulky_event_type_id => 1636,
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
            form_name => 'rbk_user_form',
            staff_form_name => 'rbk_staff_form',
            customer_ref => 'customer-ref',
            bulky_customer_ref => 'customer-ref-bulky',
        } },
    },
}, sub {
    my $lwp = Test::MockModule->new('LWP::UserAgent');
    $lwp->mock(
        'get',
        sub {
            my ( $ua, $url ) = @_;
            return $lwp->original('get')->(@_) unless $url =~ /example.com/;
            my ( $uprn, $area ) = ( 1000000002, "KINGSTON UPON THAMES" );
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
    $echo->mock( 'GetServiceUnitsForObject', sub { [] } );
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
    $echo->mock('ReserveAvailableSlotsForEvent', sub {
        my ($self, $service, $event_type, $property, $guid, $start, $end) = @_;
        is $service, 413;
        is $event_type, 1636;
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
        $mech->submit_form_ok( { with_fields => { postcode => 'KT1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );

        $mech->content_lacks('Bulky Waste');
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

        $mech->content_contains('Bulky Waste');
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

        subtest 'higher band try' => sub {
            $mech->submit_form_ok(
                {   with_fields => {
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
            $mech->content_contains('you can add up to 3 more items');
            $mech->content_contains('£61.00');
            $mech->back;
            $mech->back;
        };

        $mech->submit_form_ok(
            {   with_fields => {
                    'item_1' => 'BBQ',
                    'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                    'item_2' => 'Bicycle',
                    'item_3' => 'Bath',
                },
            },
        );
        $mech->submit_form_ok({ with_fields => { location => '' } }, 'Will error with a blank location');
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });

        sub test_summary {
            $mech->content_contains('Booking Summary');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('you can add up to 5 more items');
            $mech->content_contains('No image of the location has been attached.');
            $mech->content_contains('£40.00');
            $mech->content_contains("<dd>01 July</dd>");
            $mech->content_contains("06:30 on 01 July 2023");
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
                $mech->content_contains("<dd>08 July</dd>");
                $mech->content_contains("06:30 on 08 July 2023");
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

        subtest 'Payment page' => sub {
            my ( $token, $new_report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

            is $new_report->category, 'Bulky collection', 'correct category on report';
            is $new_report->title, 'Bulky goods collection', 'correct title on report';
            is $new_report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
            is $new_report->state, 'confirmed', 'report confirmed';

            is $sent_params->{items}[0]{amount}, 4000, 'correct amount used';
            is $sent_params->{items}[0]{reference}, 'customer-ref-bulky';
            is $sent_params->{items}[0]{lineId}, 'RBK-BULKY-' . $new_report->id . '-' . $new_report->name;

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

            $mech->get_ok("/waste/pay_complete/$report_id/$token");
            is $sent_params->{scpReference}, 12345, 'correct scpReference sent';

            $new_report->discard_changes;
            is $new_report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

            my $update = $new_report->comments->first;
            is $update->state, 'confirmed';
            is $update->text, 'Payment confirmed, reference 54321, amount £40.00';
        };

        subtest 'Confirmation page' => sub {
            $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            $mech->content_contains('Bulky collection booking confirmed');
            $mech->content_contains('Our contractor will collect the items you have requested on 08 July.');
            $mech->content_contains('Item collection starts from 6:30am. Please have your items ready and dismantled if required.');
            $mech->content_contains('We have emailed confirmation of your booking to pkg-tappcontrollerwaste_kands_bulkyt-bob@example.org.');
            $mech->content_contains('If you need to contact us about your application please use the application reference:&nbsp;RBK-' . $report->id);
            $mech->content_contains('Card payment reference: 54321');
            $mech->content_contains('Return to property details');
            is $report->detail, "Address: 2 Example Street, Kingston, KT1 1AA";
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
        };
    };

    # Collection date: 2023-07-01T00:00:00
    # Time/date that is within the cancellation window:
    my $good_date = '2023-06-25T05:44:59Z'; # 06:44:59 UK time

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
            $mech->content_contains('you can add up to 5 more items');
            $mech->content_contains('£40.00');
            $mech->content_contains('08 July');
            $mech->content_lacks('Request a bulky waste collection');
            $mech->content_contains('Your bulky waste collection');
            $mech->content_contains('Show upcoming bin days');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');

            set_fixed_time($good_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains("06:30 on 08 July 2023");

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

    subtest 'Cancellation' => sub {
        my $base_path = '/waste/12345';
        $mech->get_ok($base_path);
        $mech->content_contains('Cancel booking');
        $mech->get_ok("$base_path/bulky/cancel/" . $report->id);
        $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
        $mech->content_contains('Your booking has been cancelled');
        $mech->follow_link_ok( { text => 'Return to property details' } );
        is $mech->uri->path, $base_path, 'Returned to bin days';
        $mech->content_lacks('Cancel booking');

        $report->discard_changes;
        is $report->state, 'closed', 'Original report closed';
        like $report->detail, qr/Cancelled at user request/, 'Original report detail field updated';

        subtest 'Viewing original report summary after cancellation' => sub {
            my $id   = $report->id;
            $mech->get_ok("/report/$id");
            $mech->content_contains('This collection has been cancelled');
            $mech->content_lacks("You can cancel this booking till");
            $mech->content_lacks('Cancel this booking');
        };
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
