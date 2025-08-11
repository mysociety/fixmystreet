use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use Path::Tiny;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $guid = Test::MockModule->new('UUID::Tiny');
$guid->mock('create_uuid_as_string', sub { '4ea70923-7151-11f0-aeea-cd51f3977c8c' });

my $mech = FixMyStreet::TestMech->new;
my $sample_file = path(__FILE__)->parent->child("sample.jpg");

my $sutton = $mech->create_body_ok( 2498, 'Sutton Borough Council', { cobrand => 'sutton' } );
$sutton->set_extra_metadata(wasteworks_config => {
    small_items_per_collection_max => '6',
    small_item_list => [{bartec_id => 1, max => 1, message => '', name => 'Batteries', price => ''}, {bartec_id => 2, max => 6, message => '', name => 'Small WEEE', price => ''}],
    show_location_page => "users",
   });
$sutton->update;

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $sutton, %$params, group => ['Waste'], extra => { type => 'waste' }, email => 'test@test.com');
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
    { code => 'Collection_Date_-_Bulky_Items', required => 0, automated => 'hidden_field' },
    { code => 'TEM_-_Small_Item_Collection_Description', required => 0, automated => 'hidden_field' },
    { code => 'TEM_-_Small_Item_Recycling_Item', required => 0, automated => 'hidden_field' },
    { code => 'Exact_Location' },
    { code => 'GUID' },
    { code => 'reservation' },
);

my $user = $mech->create_user_ok('maryk@example.org', name => 'Test User');

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'sutton',
    COBRAND_FEATURES => {
        waste => { sutton => 1 },
        waste_features => {
            sutton => {
                small_items_enabled => 1,
                small_items_tandc_link => 'tandc_link',
                small_items_multiple_bookings => 1,
            },
        },
        echo => {
            sutton => {
                small_items_service_id => 274,
                small_items_event_type_id => 2964,
                bulky_address_types => [ 1, 7 ],
                url => 'http://example.org',
            },
        },
    }
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    subtest 'Eligible property' => sub {
        $echo->mock('call', sub { die; });
        $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 943 }] } );
        $echo->mock( 'GetEventsForObject',       sub { [] } );
        $echo->mock( 'ReserveAvailableSlotsForEvent', sub { return [
                                    {
                                        StartDate => { DateTime => '2025-08-08T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-09T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7a==',
                                    },
                                    {
                                        StartDate => { DateTime => '2025-08-10T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-11T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7b==',
                                    },
                                    {
                                        StartDate => { DateTime => '2025-08-11T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-12T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7c==',
                                    },
                                    {
                                        StartDate => { DateTime => '2025-08-12T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-13T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7d==',
                                    },
                                    {
                                        StartDate => { DateTime => '2025-08-13T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-14T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7e==',
                                    },
                                    {
                                        StartDate => { DateTime => '2025-08-14T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-15T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7f==',
                                    },
                                    {
                                        StartDate => { DateTime => '2025-08-15T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-16T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7g==',
                                    },
                                    {
                                        StartDate => { DateTime => '2025-08-16T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-17T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7h==',
                                    },
                                    {
                                        StartDate => { DateTime => '2025-08-17T00:00:00Z' },
                                        EndDate => { DateTime => '2025-08-18T00:00:00Z' },
                                        Expiry => { DateTime => '2025-08-25T10:20:00Z' },
                                        Reference => 'reserve7i==',
                                    },
                ];
        });
        $echo->mock(
            'FindPoints',
            sub {
                [   {   Description => '2 Example Street, Sutton, SM2 5HF',
                        Id          => '12345',
                        SharedRef   => { Value => { anyType => 1000000002 } }
                    },
                ]
            }
        );
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
                            { Latitude => 51.354679, Longitude => -0.183895 }
                    },
                    Description => '2 Example Street, Sutton, SM2 5HF',
                };
            }
        );

        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'SM2 5HF' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );
        $mech->content_lacks('/waste/12345/small_items', "Small bookings link not available with only communal waste");
        $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 940 }] } );
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'SM2 5HF' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );
        $mech->content_contains('/waste/12345/small_items', "Small bookings link available for property with domestic waste");
        $mech->content_contains('Book a collection', "Small bookings link available for property with domestic waste");
        $mech->content_lacks('View existing bookings', "No previous bookings");
    };

    subtest 'Introduction page' => sub {
        $mech->get_ok('/waste/12345/small_items');

        $mech->content_contains('Before you start your booking', "On booking introduction page");
        $mech->content_contains('2 Example Street, Sutton, SM2 5HF', "Shows correct address");
        $mech->content_contains('a href="tandc_link"', "Link picked up from config");
        $mech->content_contains('There is a maximum of 6 items for a collection', "Max items picked up from config");
    };

    subtest 'About you' => sub {
        $mech->submit_form_ok();
        $mech->content_contains('About you', "On booking 'About you' page");
        $mech->content_contains('2 Example Street, Sutton, SM2 5HF', "Shows correct address");
        $mech->submit_form_ok();
        $mech->content_contains('Error:</span> Your name is required', "Name is required");
        $mech->content_contains('Error:</span> Please provide an email address', "Email address required");
        $mech->submit_form_ok( { with_fields => { name => 'Mary Kay', email => $user->email } });
    };

    subtest 'Select dates' => sub {
        $mech->content_contains('Choose date for collection', "On 'Available dates' page");
        $mech->content_contains('2 Example Street, Sutton, SM2 5HF', "Shows correct address");
        $mech->content_contains('Friday  8 August', "Readable date correct");
        $mech->content_contains('2025-08-08T00:00:00;reserve7a==;2025-08-25T10:20:00', "Date value correct");
        $mech->content_contains('Sunday 10 August', "Readable date correct");
        $mech->content_contains('2025-08-10T00:00:00;reserve7b==;2025-08-25T10:20:00', "Date value correct");
        for my $date ('Monday 11 August', 'Tuesday 12 August', 'Wednesday 13 August', 'Thursday 14 August'
        , 'Friday 15 August', 'Saturday 16 August') {
            $mech->content_contains($date, 'Date 3-8 included as well');
        };
        $mech->content_lacks('Sunday 17 August', 'Ninth date not included as only eight required');
        $mech->submit_form_ok();
        $mech->content_contains('Error:</span> Available dates field is required', "Choosing a date is required");
        $mech->submit_form_ok( { with_fields => { chosen_date => '2025-08-08T00:00:00;reserve7a==;2025-08-25T10:20:00'}});
    };

    subtest 'List items' => sub {
        $mech->content_contains('Add items for collection', "On items page");
        # Why not?
        #$mech->content_contains('2 Example Street, Sutton, SM2 5HF', "Shows correct address");
        $mech->content_contains('option value="Batteries"', "Batteries option");
        $mech->content_contains('option value="Small WEEE"', "Small WEEE option");
        $mech->submit_form_ok( { fields => { 'item_1' => 'Batteries', 'item_2' => 'Batteries' } });
        $mech->content_contains( 'Item note field is required');
        $mech->content_contains( 'Too many of item: Batteries');
        $mech->submit_form_ok( { fields => { 'item_1' => 'Batteries', 'item_notes_1' => 'A bag of batteries', 'item_2' => 'Small WEEE', 'item_notes_2' => 'A toaster', 'item_photo_2' => [ $sample_file, undef, Content_Type => 'image/jpeg' ], } });
    };

    subtest 'Location page' => sub {
        $mech->content_contains('Location details', "Location page included");
        $mech->content_contains('2 Example Street, Sutton, SM2 5HF', "Shows correct address");
        $mech->content_contains('Please tell us where you will place the items for collection (the small items collection crews', 'Small items collection specified');
        $mech->submit_form_ok();
        $mech->content_contains('There is a problem', "Location details are mandatory");
        $mech->submit_form_ok( { with_fields => { 'location' => 'In the alley' } } );
    };

    subtest 'Booking summary' => sub {
        $mech->content_contains('Booking Summary', "On booking confirmation page");
        $mech->content_lacks('Bookings are not refundable', "Small items service is free so no mention of refunds");
        $mech->content_contains('2 Example Street, Sutton, SM2 5HF', "Shows correct address");
        $mech->content_contains('2 items requested for collection', "2 items for collection");
        $mech->content_contains('Batteries', "Batteries added");
        $mech->content_contains('A bag of batteries', "Batteries note added");
        $mech->content_contains('Small WEEE', "Small WEEE added");
        $mech->content_contains('A toaster', "Small WEEE note added");
        $mech->content_contains('In the alley', "Location information added");
        $mech->content_contains('<a href="tandc_link" target="_blank">terms and conditions</a>', 'T&C link addeed');
        $mech->submit_form_ok({form_number => 5});
        $mech->content_contains('Terms and conditions field is required', "Can't continue without accepting T&Cs");
        $mech->submit_form_ok({form_number => 5, with_fields => { tandc => 1} });
    };

    my $report = FixMyStreet::DB->resultset("Problem")->find({ title => 'Small items collection'});
    subtest 'Booking confirmed' => sub {
        $mech->content_contains('Small items collection booking confirmed', "Booking confirmed ok");
        $mech->content_contains('Our contractor will collect the items you have requested on Friday 08 August 2025', "Date included on confirmation page");
        $mech->content_contains('Item collection starts from 6am', "Collection time included");
        $mech->content_contains('We have emailed confirmation of your booking to ' . $user->email, "Email address included");
        $mech->content_contains('If you need to contact us about your application please use the application reference:&nbsp;LBS-' . $report->id, "Reference included");
    };

    subtest 'Report made'  => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('View existing bookings', "Small items booking registered");
        # Why not?
        #is $report->user->name, 'Mary Kay', "Report made by user";
        is $report->user->email, $user->email, "Report made by user";
        my $test_extra = [
          {
            'value' => '1000000002',
            'description' => undef,
            'name' => 'uprn'
          },
          {
            'name' => 'property_id',
            'description' => undef,
            'value' => '12345'
          },
          {
            'name' => 'service_id',
            'description' => undef,
            'value' => ''
          },
          {
            'description' => undef,
            'value' => '2025-08-08T00:00:00',
            'name' => 'Collection_Date_-_Bulky_Items'
          },
          {
            'value' => 'A bag of batteries::A toaster',
            'description' => undef,
            'name' => 'TEM_-_Small_Item_Collection_Description'
          },
          {
            'value' => '1::2',
            'name' => 'TEM_-_Small_Item_Recycling_Item',
            'description' => undef
          },
          {
            'value' => 'In the alley',
            'description' => undef,
            'name' => 'Exact_Location'
          },
          {
            'name' => 'GUID',
            'description' => undef,
            'value' => '4ea70923-7151-11f0-aeea-cd51f3977c8c'
          },
          {
            'value' => 'reserve7a==',
            'description' => undef,
            'name' => 'reservation'
          }
        ];
        is_deeply $report->get_extra_fields, $test_extra, "Data added to report";
    };

    subtest 'Viewing existing booking' => sub {
        $mech->log_in_ok($report->user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('report/' . $report->id .'">Check collection details', 'Link to view collection');
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('Your small items collection', 'Correct collection type');
        $mech->content_contains('Booking Summary', 'On summary page');
        $mech->content_contains('Mary Kay', 'Name from booking form');
        $mech->content_contains($user->email, 'Correct email address');
        $mech->content_contains('Example Street, Sutton, SM2 5HF', 'Correct property address');
        $mech->content_contains('Friday 08 August 2025', 'Collection date correct');
        $mech->content_contains('2 items requested for collection', 'Correct number of items');
        $mech->content_contains('Batteries', 'item 1 added');
        $mech->content_contains('A bag of batteries', 'item 1 notes added');
        $mech->content_contains('Small WEEE', 'item 2 added');
        $mech->content_contains('A toaster', 'item 2 notes added');
        $mech->content_contains('Preview image successfully attached', 'Preview image added');
        $mech->content_contains('In the alley', 'Location details present');
    };

    subtest 'Can not make another booking for the same day' => sub {
        $mech->get_ok('/waste/12345/small_items');
        $mech->submit_form_ok();
        $mech->submit_form_ok( { with_fields => { name => 'Mary Kay', email => 'maryk@example.org'} });
        $mech->content_unlike(qr/Friday\s+8 August/, 'No date offered where current booking');
        for my $date ('Sunday 10 August', 'Monday 11 August', 'Tuesday 12 August', 'Wednesday 13 August', 'Thursday 14 August',
        'Friday 15 August', 'Saturday 16 August', 'Sunday 17 August') {
            $mech->content_contains($date, 'Date 2-9 included');
        };
    }

};

done_testing;
