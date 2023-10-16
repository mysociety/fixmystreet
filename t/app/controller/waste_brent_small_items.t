use utf8;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use Path::Tiny;
use FixMyStreet::Script::Reports;

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
        show_individual_notes => 1,
        item_list => [
            { bartec_id => '1', name => 'Tied bag of domestic batteries (min 10 - max 100)', max => '1' },
            { bartec_id => '2', name => 'Podback Bag' },
            { bartec_id => '3', name => 'Paint, up to 5 litres capacity (1 x 5 litre tin, 5 x 1 litre tins etc.)' },
            { bartec_id => '4', name => 'Textiles, up to 60 litres (one black sack / 3 carrier bags)' },
            { bartec_id => '5', name => 'Toaster', category => 'Small electrical items' },
            { bartec_id => '6', name => 'Kettle', category => 'Small electrical items' },
            { bartec_id => '7', name => 'Games console', category => 'Small electrical items' },
            { bartec_id => '8', name => 'Small electricals: Other item under 30x30x30 cm', category => 'Small electrical items' },
        ],
    },
);
$body->update;

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste'], extra => { type => 'waste' }, email => 'test@test.com');
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

create_contact(
    { category => 'Small items collection', email => '2964@test.com' },
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
                bulky_missed => 1,
                bulky_multiple_bookings => 1,
                bulky_tandc_link => 'tandc_link',
            },
        },
        echo => {
            brent => {
                bulky_service_id => 274,
                bulky_event_type_id => 2964,
                url => 'http://example.org',
            },
        },
        anonymous_account => { brent => 'anonymous.customer' },
    },
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock( 'GetServiceUnitsForObject', sub { [ {
        Id => 1002,
        ServiceId => 262,
        ServiceName => 'Domestic Refuse Collection',
        ServiceTasks => { ServiceTask => {
            Id => 402,
            ServiceTaskSchedules => { ServiceTaskSchedule => {
                ScheduleDescription => 'every other Wednesday',
                Allocation => {
                    RoundName => 'Friday ',
                    RoundGroupName => 'Delta 04 Week 2',
                },
                StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                NextInstance => {
                    CurrentScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                    OriginalScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                },
                LastInstance => {
                    OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                    CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                    Ref => { Value => { anyType => [ 234, 567 ] } },
                },
            } },
        } },
    } ] } );
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
        is $service, 274;
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

    $mech->content_contains('small items');
    $mech->submit_form_ok({ form_number => 2 }); # 'Book Collection'

    $mech->content_contains( 'Before you start your booking',
        'Should be able to access the booking form' );

    my $report;
    subtest 'Small items collection booking' => sub {
        $mech->get_ok('/waste/12345/small_items');

        subtest 'Intro page' => sub {
            $mech->content_contains('Book small items collection');
            $mech->content_contains('Before you start your booking');
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
                    'item_2' => 'Toaster',
                    'item_3' => 'Podback Bag',
                    'item_5' => 'Small electricals: Other item under 30x30x30 cm',
                    'item_notes_5' => 'A widget',
                },
            },
        );
        $mech->submit_form_ok({ with_fields => { location => 'in the middle of the drive' } });

        sub test_summary {
            $mech->content_contains('Booking Summary');
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Tied bag of domestic batteries/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Podback Bag/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Other.*/s);
            $mech->content_like(qr/<p class="govuk-!-margin-bottom-0">.*Toaster/s);
            $mech->content_contains('4 items requested for collection');
            $mech->content_lacks('you can add up to');
            $mech->content_contains('No image of the location has been attached.');
            $mech->content_lacks('£0.00');
            $mech->content_contains("<dd>01 July</dd>");
            $mech->content_contains("23:59 on the night before");
        }

        subtest 'Summary page' => \&test_summary;
        $mech->submit_form_ok({ with_fields => { tandc => 1 } });

        subtest 'Confirmation page' => sub {
            $mech->content_contains('Small items collection booking confirmed');

            $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;

            is $report->category, 'Small items collection', 'correct category on report';
            is $report->title, 'Small items collection', 'correct title on report';
            is $report->get_extra_field_value('payment_method'), undef;
            is $report->state, 'confirmed', 'report confirmed';
            is $report->detail, "Address: 1 Example Street, Brent, HA0 5HF";
            is $report->get_extra_field_value('uprn'), 1000000002;
            is $report->get_extra_field_value('Collection_Date'), '2023-07-01T00:00:00';

            is $report->get_extra_field_value('Notes'), "Collection date: 01 July\n1 x Podback Bag\n1 x Small electricals: Other item under 30x30x30 cm (A widget)\n1 x Tied bag of domestic batteries (min 10 - max 100)\n1 x Toaster";
            is $report->get_extra_field_value('Textiles'), '';
            is $report->get_extra_field_value('Paint'), '';
            is $report->get_extra_field_value('Batteries'), 1;
            is $report->get_extra_field_value('Small_WEEE'), 1;
            is $report->get_extra_field_value('Coffee_Pods'), 1;

            is $report->get_extra_field_value('property_id'), '12345';
            like $report->get_extra_field_value('GUID'), qr/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/;
            is $report->get_extra_field_value('reservation'), 'reserve1==';
            is $report->photo, undef;
        };
    };

    subtest 'Bulky goods email confirmation and reminders' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        $report->confirmed('2023-08-30T00:00:00');
        $report->update;
        my $id = $report->id;
        subtest 'Email confirmation of booking' => sub {
            FixMyStreet::Script::Reports::send();
            my @emails = $mech->get_email;
            my $confirmation_email_txt = $mech->get_text_body_from_email($emails[1]);
            my $confirmation_email_html = $mech->get_html_body_from_email($emails[1]);
            like $emails[1]->header('Subject'), qr/Small items collection service - reference $id/, 'Small items in email subject';
            like $confirmation_email_txt, qr/Date booking made: 30 August/, 'Includes booking date';
            like $confirmation_email_txt, qr/The report's reference number is $id/, 'Includes reference number';
            like $confirmation_email_txt, qr/Items to be collected:/, 'Includes header for items';
            like $confirmation_email_txt, qr/- Tied bag of domestic batteries \(min 10 - max 100\)/, 'Includes item 1';
            like $confirmation_email_txt, qr/- Toaster/, 'Includes item 2';
            like $confirmation_email_txt, qr/- Podback Bag/, 'Includes item 3';
            like $confirmation_email_txt, qr/- Small electricals: Other/, 'Includes item 3';
            unlike $confirmation_email_txt, qr/Total cost/, 'There is not total cost';
            like $confirmation_email_txt, qr/Address: 1 Example Street, Brent, HA0 5HF/, 'Includes collection address';
            like $confirmation_email_txt, qr/Collection date: 01 July/, 'Includes collection date';
            like $confirmation_email_txt, qr#http://brent.example.org/waste/12345/small_items/cancel/$id#, 'Includes cancellation link';
            like $confirmation_email_txt, qr/Please check you have read the terms and conditions tandc_link/, 'Includes terms and conditions';
            like $confirmation_email_html, qr/Date booking made: 30 August/, 'Includes booking date (html mail)';
            like $confirmation_email_html, qr#The report's reference number is <strong>$id</strong>#, 'Includes reference number (html mail)';
            like $confirmation_email_html, qr/Items to be collected:/, 'Includes header for items (html mail)';
            like $confirmation_email_html, qr/Tied bag of domestic batteries \(min 10 - max 100\)/, 'Includes item 1 (html mail)';
            like $confirmation_email_html, qr/Toaster/, 'Includes item 2 (html mail)';
            like $confirmation_email_html, qr/Podback Bag/, 'Includes item 3 (html mail)';
            like $confirmation_email_html, qr/Small electricals: Other/, 'Includes item 3 (html mail)';
            unlike $confirmation_email_html, qr/Total cost/, 'There is no total cost (html mail)';
            like $confirmation_email_html, qr/Address: 1 Example Street, Brent, HA0 5HF/, 'Includes collection address (html mail)';
            like $confirmation_email_html, qr/Collection date: 01 July/, 'Includes collection date (html mail)';
            like $confirmation_email_html, qr#http://brent.example.org/waste/12345/small_items/cancel/$id#, 'Includes cancellation link (html mail)';
            $mech->clear_emails_ok;
        };

        subtest 'Reminder email' => sub {
            set_fixed_time('2023-06-28T05:44:59Z');
            my $cobrand = $body->get_cobrand_handler;
            $cobrand->bulky_reminders;
            my $email = $mech->get_email;
            my $confirmation_email_txt = $mech->get_text_body_from_email($email);
            my $confirmation_email_html = $mech->get_html_body_from_email($email);
            like $email->header('Subject'), qr/Small items collection reminder - reference $id/, 'Small items in email subject';
            like $confirmation_email_txt, qr/Thank you for booking a small items collection with Brent Council/, 'Includes Brent greeting';
            like $confirmation_email_txt, qr/The report's reference number is $id/, 'Includes reference number';
            like $confirmation_email_txt, qr/Address: 1 Example Street, Brent, HA0 5HF/, 'Includes collection address';
            like $confirmation_email_txt, qr/Collection date: 01 July/, 'Includes collection date';
            like $confirmation_email_txt, qr/- Tied bag of domestic batteries \(min 10 - max 100\)/, 'Includes item 1';
            like $confirmation_email_txt, qr/- Toaster/, 'Includes item 2';
            like $confirmation_email_txt, qr/- Podback Bag/, 'Includes item 3';
            like $confirmation_email_txt, qr/- Small electricals: Other item under 30x30x30 cm \(A widget\)/, 'Includes item 3';
            like $confirmation_email_txt, qr#http://brent.example.org/waste/12345/small_items/cancel/$id#, 'Includes cancellation link';
            like $confirmation_email_html, qr/Thank you for booking a small items collection with Brent Council/, 'Includes Brent greeting (html mail)';
            like $confirmation_email_html, qr#The report's reference number is <strong>$id</strong>#, 'Includes reference number (html mail)';
            like $confirmation_email_html, qr/Address: 1 Example Street, Brent, HA0 5HF/, 'Includes collection address (html mail)';
            like $confirmation_email_html, qr/Collection date: 01 July/, 'Includes collection date (html mail)';
            like $confirmation_email_html, qr/Tied bag of domestic batteries \(min 10 - max 100\)/, 'Includes item 1 (html mail)';
            like $confirmation_email_html, qr/Toaster/, 'Includes item 2 (html mail)';
            like $confirmation_email_html, qr/Podback Bag/, 'Includes item 3 (html mail)';
            like $confirmation_email_html, qr/Small electricals: Other item under 30x30x30 cm \(A widget\)/, 'Includes item 3 (html mail)';
            like $confirmation_email_html, qr#http://brent.example.org/waste/12345/small_items/cancel/$id#, 'Includes cancellation link (html mail)';
            $mech->clear_emails_ok;
        }
    };

    my %error_messages = (
                            'weee' => 'Too many small electrical items: maximum 4',
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
                items => &item_fields('Tied bag of domestic batteries (min 10 - max 100)', 'Toaster',
                  'Podback Bag', 'Paint, up to 5 litres capacity (1 x 5 litre tin, 5 x 1 litre tins etc.)' ),
                content_contains => [$error_messages{categories}],
                content_lacks => [$error_messages{weee}, $error_messages{peritem}]
            },
            {
                items => &item_fields('Toaster', 'Kettle', 'Games console',
                    'Toaster', 'Kettle', 'Podback Bag', 'Up to 5 litres capacity (1 x 5 litre tin, 5 x 1 litre tins etc.)' ),
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
                'Toaster', 'Kettle', 'Games console', 'Toaster', 'Kettle'),
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
            $mech->content_contains('A widget');
            $mech->content_contains('4 items requested for collection');
            $mech->content_lacks('you can add up to');
            $mech->content_lacks('£0.00');
            $mech->content_contains('01 July');
            $mech->content_lacks('Request a small items collection');
            $mech->content_contains('Your small items collection');
            $mech->content_contains('Show upcoming bin days');

            # Cancellation messaging & options
            $mech->content_lacks('This collection has been cancelled');
            $mech->content_lacks('View cancellation report');

            set_fixed_time($good_date);
            $mech->get_ok('/report/' . $report->id);
            $mech->content_contains("you can cancel the booking up to 23:59 on the night before");

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
        $mech->get_ok("$base_path/small_items/cancel/" . $report->id);
        $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
        $mech->content_contains('Your booking has been cancelled');
        $mech->follow_link_ok( { text => 'Show upcoming bin days' } );
        is $mech->uri->path, $base_path, 'Returned to bin days';
        $mech->content_lacks('Cancel booking');

        $report->discard_changes;
        is $report->state, 'closed', 'Original report closed';
        like $report->detail, qr/Cancelled at user request/, 'Original report detail field updated';

        subtest 'Viewing original report summary after cancellation' => sub {
            my $id   = $report->id;
            $mech->get_ok("/report/$id");
            $mech->content_contains('This collection has been cancelled');
            $mech->content_lacks("you can cancel the booking up to 23:59 on the night before");
            $mech->content_lacks('Cancel this booking');
        };
    };

    subtest 'Missed collections' => sub {
        # Fixed date still set to 5th July
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a small items collection as missed');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Small items collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            EventTypeId => 2964,
            ResolvedDate => { DateTime => '2023-06-21T00:00:00Z' },
            ResolutionCodeId => 232,
            EventStateId => 18490,
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Report a small items collection as missed', 'Too long ago');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Small items collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            EventTypeId => 2964,
            ResolvedDate => { DateTime => '2023-06-25T00:00:00Z' },
            ResolutionCodeId => 232,
            EventStateId => 18490,
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a small items collection as missed', 'In time, normal completion');
        $mech->get_ok('/waste/12345/report');
        $mech->content_contains('Small items collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            EventTypeId => 2964,
            ResolvedDate => { DateTime => '2023-06-25T00:00:00Z' },
            ResolutionCodeId => 379,
            EventStateId => 18491,
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A missed collection cannot be reported', 'Not completed');
        $mech->content_contains('could not be completed');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Small items collection');
        $echo->mock( 'GetEventsForObject', sub { [ {
            EventTypeId => 2964,
            ResolvedDate => { DateTime => '2023-06-25T00:00:00Z' },
            EventStateId => 18490,
        }, {
            EventTypeId => 2891,
            ServiceId => 274,
            Guid => 'guid',
            EventDate => { DateTime => '2023-07-05T00:00:00Z' },
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->content_contains('A small items collection has been reported as missed');
        $mech->get_ok('/waste/12345/report');
        $mech->content_lacks('Small items collection');
        $echo->mock( 'GetEventsForObject', sub { [] } );
    };
};

done_testing;
