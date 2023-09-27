use utf8;
use Test::MockModule;
use Test::MockTime 'set_fixed_time';
use FixMyStreet::TestMech;
use Path::Tiny;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;
my $sample_file = path(__FILE__)->parent->child("sample.jpg");

my $user = $mech->create_user_ok('bob@example.org');

my $body = $mech->create_body_ok( 2482, 'Bromley Council',
    {}, { cobrand => 'bromley' } );
$body->set_extra_metadata(
    wasteworks_config => {
        per_item_costs => 1,
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
    { category => 'Bulky collection', email => '1636' },
    { code => 'Collection_Date' },
    { code => 'Exact_Location' },
    { code => 'payment' },
    { code => 'payment_method' },
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
        waste => { bromley => 1 },
        waste_features => {
            bromley => {
                bulky_trade_service_id => 532,
                bulky_enabled => 1,
                bulky_tandc_link => 'tandc_link',
            },
        },
        echo => {
            bromley => {
                bulky_service_id => 413,
                bulky_event_type_id => 1636,
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
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });

        sub test_summary {
            $mech->content_contains('Booking Summary');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bicycle/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*BBQ/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Bath/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('5 remaining slots available');
            $mech->content_contains('No image of the location has been attached.');
            $mech->content_contains('£30.00');
            $mech->content_contains("<dd>01 July</dd>");
            $mech->content_contains("06:30 on 01 July 2023");
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
            is $report->photo, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';
        };
    };

    # Collection time: 2023-07-01T:06:30:00
    # Time within the cancellation window:
    my $cancell_allowed_time = '2023-07-01T05:29:59Z'; # 06:29:59 UK time

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
            $mech->content_contains('5 remaining slots available');
            $mech->content_contains('£30.00');
            $mech->content_contains('01 July');
            $mech->content_lacks('Request a bulky waste collection');
            $mech->content_contains('Your bulky waste collection');
            $mech->content_contains('Show upcoming bin days');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');

            set_fixed_time($cancell_allowed_time);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains("06:30 on 01 July 2023");

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

    $report->comments->delete;
    $report->delete;

    subtest 'Different pricing depending on domestic or trade property' => sub {
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
        $echo->mock('GetServiceUnitsForObject', \&trade_waste_service_units );
        test_prices('£20.00', '£20.00');
        $echo->mock('GetServiceUnitsForObject', \&domestic_waste_service_units );
        test_prices('£10.00', '£10.00');
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
