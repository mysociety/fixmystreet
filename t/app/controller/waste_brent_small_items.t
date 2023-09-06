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

my $body = $mech->create_body_ok(2488, 'Brent Council', {}, { cobrand => 'brent' });
$body->set_extra_metadata(
    wasteworks_config => {
        items_per_collection_max => 11,
        base_price => 0,
        show_location_page => 'users',
        item_list => [
            { bartec_id => '1', name => 'Tied bag of domestic batteries (min 10 - max 100)', max => '1' },
            { bartec_id => '2', name => 'Podback Bag' },
            { bartec_id => '3', name => 'Paint, up to 5 litres capacity (1 x 5 litre tin, 5 x 1 litre tins etc.)' },
            { bartec_id => '4', name => 'Textiles, up to 60 litres (one black sack / 3 carrier bags)' },
            { bartec_id => '5', name => 'Small WEEE: Toaster', category => 'Small WEEE' },
            { bartec_id => '6', name => 'Small WEEE: Kettle', category => 'Small WEEE' },
            { bartec_id => '7', name => 'Small WEEE: Games console', category => 'Small WEEE' },
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
    { category => 'Small items collection', email => '2964' },
    { code => 'Collection_Date' },
    { code => 'Notes' },
    { code => 'Textiles' },
    { code => 'Small_WEEE' },
    { code => 'Paint' },
    { code => 'Coffee_Pods' },
    { code => 'Batteries' },
    { code => 'Exact_Location' },
    { code => 'GUID' },
    { code => 'reservation' },
);

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'brent',
    COBRAND_FEATURES => {
        waste => { brent => 1 },
        waste_features => {
            brent => {
                bulky_enabled => 1,
                bulky_tandc_link => 'tandc_link',
            },
        },
        echo => {
            brent => {
                bulky_service_id => 787,
                bulky_event_type_id => 2964,
                url => 'http://example.org',
            },
        },
        anonymous_account => { brent => 'anonymous.customer' },
    },
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock( 'GetServiceUnitsForObject', sub { [] } );
    $echo->mock( 'GetTasks', sub { [] } );
    $echo->mock( 'GetEventsForObject', sub { [] } );
    $echo->mock( 'FindPoints', sub { [
        { Description => '1 Example Street, Brent, HA0 5HF', Id => '12345', SharedRef => { Value => { anyType => 1000000002 } } },
    ] });
    $echo->mock('GetPointAddress', sub {
        return {
            Id => '12345',
            PointAddressType => { Id => 1, Name => 'Detached', },
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            Coordinates => { GeoPoint => { Latitude => 51.55904, Longitude => -0.28168 } },
            Description => '1 Example Street, Brent, HA0 5HF',
        };
    });
    $echo->mock('ReserveAvailableSlotsForEvent', sub {
        my ($self, $service, $event_type, $property, $guid, $start, $end) = @_;
        is $service, 787;
        is $event_type, 2964;
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
    $echo->mock('CancelReservedSlotsForEvent', sub { });

    $mech->get_ok('/waste');
    $mech->submit_form_ok( { with_fields => { postcode => 'HA0 5HF' } } );
    $mech->submit_form_ok( { with_fields => { address => '12345' } } );

    #$mech->content_contains('small items');
    #$mech->submit_form_ok; # 'Book Collection'
    $mech->get_ok('/waste/12345/small_items');

    $mech->content_contains( 'Before you start your booking',
        'Should be able to access the booking form' );

    my $report;
    subtest 'Small items collection booking' => sub {
        $mech->get_ok('/waste/12345/small_items');

        subtest 'Intro page' => sub {
            $mech->content_contains('Book small items collection');
            $mech->content_contains('Before you start your booking');
            $mech->content_contains('You can request up to <strong>eleven items per collection');
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
                    'item_1' => 'Tied bag of domestic batteries (min 10 - max 100)',
                    'item_photo_1' => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
                    'item_2' => 'Small WEEE: Toaster',
                    'item_3' => 'Podback Bag',
                },
            },
        );
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });

        sub test_summary {
            $mech->content_contains('Booking Summary');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Tied bag of domestic batteries/s);
            $mech->content_contains('<img class="img-preview is--small" alt="Preview image successfully attached" src="/photo/temp.74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg">');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Podback Bag/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Small WEEE: Toaster/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('8 remaining slots available');
            $mech->content_lacks('No image of the location has been attached.');
            $mech->content_contains('£0.00'); # TODO Don't show pricing at all
            $mech->content_contains("<dd>01 July</dd>");
            $mech->content_contains("06:00 on 01 July 2023");
        }

        subtest 'Summary page' => \&test_summary;
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        subtest 'Confirmation page' => sub {
            $mech->content_contains('Collection booked');

            $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;

            is $report->category, 'Small items collection', 'correct category on report';
            is $report->title, 'Small items collection', 'correct title on report';
            is $report->get_extra_field_value('payment_method'), undef;
            is $report->state, 'confirmed', 'report confirmed';
            is $report->detail, "Address: 1 Example Street, Brent, HA0 5HF";
            is $report->get_extra_field_value('uprn'), 1000000002;
            is $report->get_extra_field_value('Collection_Date'), '2023-07-01T00:00:00';

            is $report->get_extra_field_value('Notes'), "1 x Podback Bag\n1 x Small WEEE: Toaster\n1 x Tied bag of domestic batteries (min 10 - max 100)";
            is $report->get_extra_field_value('Textiles'), '';
            is $report->get_extra_field_value('Paint'), '';
            is $report->get_extra_field_value('Batteries'), 1;
            is $report->get_extra_field_value('Small_WEEE'), 1;
            is $report->get_extra_field_value('Coffee_Pods'), 1;

            is $report->get_extra_field_value('property_id'), '12345';
            like $report->get_extra_field_value('GUID'), qr/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/;
            is $report->get_extra_field_value('reservation'), 'reserve1==';
            is $report->photo, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';
        };
    };
    my %error_messages = (
                            'weee' => 'Too many Small WEEE items: maximum 4',
                            'categories' => 'Too many categories: maximum of 3 types',
                            'peritem' => 'Too many of item: '
    );
    sub item_fields {
        my $stem = 'item_';
        my %item_list;
        my $num = 1;
        for my $item (@_) {
            $item_list{$stem . $num++} = $item;
        };
        return \%item_list;
    };

    for my $test (
            {
                items => &item_fields('Tied bag of domestic batteries (min 10 - max 100)', 'Small WEEE: Toaster',
                  'Podback Bag', 'Paint, up to 5 litres capacity (1 x 5 litre tin, 5 x 1 litre tins etc.)' ),
                content_contains => [$error_messages{categories}],
                content_lacks => [$error_messages{weee}, $error_messages{peritem}]
            },
            {
                items => &item_fields('Small WEEE: Toaster', 'Small WEEE: Kettle', 'Small WEEE: Games console',
                    'Small WEEE: Toaster', 'Small WEEE: Kettle', 'Podback Bag', 'Up to 5 litres capacity (1 x 5 litre tin, 5 x 1 litre tins etc.)' ),
                content_contains => [$error_messages{weee}],
                content_lacks => [$error_messages{categories}, $error_messages{peritem}]
            },
            {
                items => &item_fields('Tied bag of domestic batteries (min 10 - max 100)', 'Tied bag of domestic batteries (min 10 - max 100)'),
                content_contains => [$error_messages{peritem}],
                content_lacks => [$error_messages{categories}, $error_messages{weee}]
            },
            {
                items => &item_fields('Tied bag of domestic batteries (min 10 - max 100)', 'Tied bag of domestic batteries (min 10 - max 100)',
                'Small WEEE: Toaster', 'Small WEEE: Kettle', 'Small WEEE: Games console', 'Small WEEE: Toaster', 'Small WEEE: Kettle'),
                content_contains => [$error_messages{peritem}, $error_messages{weee}],
                content_lacks => [$error_messages{categories}]
            }
        )
        {
            subtest 'Validation of items' => sub {
                $mech->get_ok('/waste/12345/small_items');
                $mech->submit_form_ok;
                $mech->submit_form_ok({ with_fields => { name => 'Bob Marge', email => $user->email }});
                $mech->submit_form_ok(
                    { with_fields => { chosen_date => '2023-07-01T00:00:00;reserve1==;2023-06-25T10:10:00' } }
                );
                $mech->submit_form_ok(
                    {  with_fields => $test->{items} }
                );
                for my $present_text (@{$test->{content_contains}}) {
                    ok $mech->content_contains($present_text);
                }
                for my $missing_text (@{$test->{content_lacks}}) {
                    ok $mech->content_lacks($missing_text);
                }
            }
    }

    # Collection date: 2023-07-01T00:00:00
    # Time/date that is within the cancellation & refund window:
    my $good_date = '2023-06-25T05:44:59Z'; # 06:44:59 UK time
    subtest 'Small items collection viewing' => sub {
        subtest 'View own booking' => sub {
            $mech->log_in_ok($report->user->email);
            $mech->get_ok('/report/' . $report->id);

            $mech->content_contains('Booking Summary');
            $mech->content_contains('1 Example Street, Brent, HA0 5HF');
            $mech->content_lacks('Please read carefully all the details');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Toaster/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*batteries/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Podback/s);
            $mech->content_contains('3 items requested for collection');
            $mech->content_contains('8 remaining slots available');
            $mech->content_contains('£0.00');
            $mech->content_contains('01 July');
            $mech->content_lacks('Request a small items collection');
            $mech->content_contains('Your bulky waste collection');
            $mech->content_contains('Show upcoming bin days');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');

            set_fixed_time($good_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("You can cancel this booking till");
            $mech->content_contains("06:00 on 01 July 2023");

            # Presence of external_id in report implies we have sent request
            # to Echo
            $mech->content_lacks('/waste/12345/small_items/cancel');
            $mech->content_lacks('Cancel this booking');

            $report->external_id('Echo-123');
            $report->update;
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains('/waste/12345/small_items/cancel');
            $mech->content_contains('Cancel this booking');
        };

        #subtest "Can follow link to booking from bin days page" => sub {
        #    $mech->get_ok('/waste/12345');
        #    $mech->follow_link_ok( { text_regex => qr/Check collection details/i, }, "follow 'Check collection...' link" );
        #    is $mech->uri->path, '/report/' . $report->id , 'Redirected to waste base page';
        #};
    };

};

done_testing;
