use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use Path::Tiny;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;

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
    { category => 'Small items collection', email => '3144' },
    { code => 'Collection_Date_-_Bulky_Items', required => 0, automated => 'hidden_field' },
    { code => 'Small_Item_Type', required => 0, automated => 'hidden_field' },
    { code => 'Exact_Location' },
    { code => 'GUID' },
    { code => 'reservation' },
);

# Missed collection contacts
create_contact(
    { category => 'Report missed collection', email => '3145' },
    { code => 'Exact_Location' },
    { code => 'Original_Event_ID' },
    { code => 'Notes' },
);
create_contact(
    { category => 'Report missed assisted collection', email => '3146' },
    { code => 'Exact_Location' },
    { code => 'Original_Event_ID' },
    { code => 'Notes' },
);

my $user = $mech->create_user_ok('maryk@example.org', name => 'Test User');
my $staff = $mech->create_user_ok('staff@example.org', name => 'Staff User', email_verified => 1, from_body => $sutton->id);
$staff->user_body_permissions->create({ body => $sutton, permission_type => 'report_inspect' });
$staff->update;
$sutton->update( { comment_user_id => $staff->id } );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'sutton',
    COBRAND_FEATURES => {
        waste => { sutton => 1 },
        waste_features => {
            sutton => {
                small_items_enabled => 1,
                small_items_missed => 1,
                small_items_tandc_link => 'tandc_link',
                small_items_multiple_bookings => 1,
                bulky_amend_enabled => 'staff',
            },
        },
        echo => {
            sutton => {
                small_items_service_id => 952,
                small_items_event_type_id => 3144,
                bulky_service_id => 960,
                bulky_address_types => [ 1, 7 ],
                url => 'http://example.org',
            },
        },
    }
}, sub {
    my $echo = Test::MockModule->new('Integrations::Echo');
    $echo->mock('call', sub { die; });
    $echo->mock( 'GetEventsForObject',       sub { [] } );
    $echo->mock( 'CancelReservedSlotsForEvent', sub {} );
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
    ] });
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

    set_fixed_time('2025-08-18T12:00:00Z');

    subtest 'Eligible property' => sub {
        $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 943 }] } );
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'SM2 5HF' } } );
        $mech->submit_form_ok( { with_fields => { address => '12345' } } );
        $mech->content_lacks('/waste/12345/small_items', "Small bookings link not available with only communal waste");
        $echo->mock( 'GetServiceUnitsForObject', sub { [{'ServiceId' => 952 }] } );
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
        $mech->content_contains( 'Too many of item: Batteries');
        $mech->submit_form_ok( { fields => { 'item_1' => 'Batteries', 'item_2' => 'Small WEEE', 'item_photo_2' => [ $sample_file, undef, Content_Type => 'image/jpeg' ], } });
    };

    subtest 'Location page' => sub {
        $mech->content_contains('Location details', "Location page included");
        $mech->content_contains('2 Example Street, Sutton, SM2 5HF', "Shows correct address");
        $mech->content_contains('Please tell us where you will place the items for collection (the small items collection crews', 'Small items collection specified');
        $mech->submit_form_ok({ form_number => 2 });
        $mech->content_contains('There is a problem', "Location details are mandatory");
        $mech->submit_form_ok( { with_fields => { 'location' => 'In the alley' } } );
    };

    subtest 'Booking summary' => sub {
        $mech->content_contains('Booking Summary', "On booking confirmation page");
        $mech->content_lacks('Bookings are not refundable', "Small items service is free so no mention of refunds");
        $mech->content_contains('2 Example Street, Sutton, SM2 5HF', "Shows correct address");
        $mech->content_contains('2 items requested for collection', "2 items for collection");
        $mech->content_contains('Batteries', "Batteries added");
        $mech->content_contains('Small WEEE', "Small WEEE added");
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
        $mech->content_contains('If you need to contact us about your booking please use the reference:&nbsp;LBS-' . $report->id, "Reference included");
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
            'value' => '1::2',
            'name' => 'Small_Item_Type',
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
        $mech->content_contains('Small WEEE', 'item 2 added');
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
    };

    my $id = $report->id;
    my $sutton_id = 'LBS-' . $id;
    subtest 'Confirmation email' => sub {
        ok $report->confirmed, "Report has been automatically confirmed";
        $report->confirmed('2025-08-01T10:00:00');
        $report->update;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $confirmation_email_txt = $mech->get_text_body_from_email($emails[1]);
        my $confirmation_email_html = $mech->get_html_body_from_email($emails[1]);
        like $emails[1]->header('Subject'), qr/Your small items collection - reference $sutton_id/, 'Small items in email subject';
        for my $email ($confirmation_email_txt, $confirmation_email_html) {
            like $email, qr/Date booking made: Friday 01 August 2025/, 'Includes booking date';
            like $email, qr/Reference: (<strong>)?$sutton_id/, 'Includes reference number';
            like $email, qr/Items to be collected:/, 'Includes header for items';
            like $email, qr/Batteries/, 'Includes item 1';
            like $email, qr/Small WEEE/, 'Includes item 2';
            unlike $email, qr/Total cost/, 'There is no total cost';
            like $email, qr/Address: 2 Example Street, Sutton, SM2 5HF/, 'Includes collection address';
            like $email, qr/Collection date: Friday 08 August/, 'Includes collection date';
            like $email, qr#http://sutton.example.org/waste/12345/small_items/cancel/$id#, 'Includes cancellation link';
            like $email, qr/tandc_link/, 'Terms and conditions link included';
        }
    };

    subtest 'Reminder emails' => sub {
        $mech->clear_emails_ok;
        my $cobrand = $sutton->get_cobrand_handler;
        for my $test (
            {
                text => 'in 3 days',
                date => '2025-08-05T10:00:00Z'
            },
            {
                text => 'tomorrow',
                date => '2025-08-07T10:00:00Z'
            },
        ) {
            $mech->clear_emails_ok;
            set_fixed_time($test->{date});
            my $text = $test->{text};
            $cobrand->bulky_reminders;
            my $email = $mech->get_email;
            like $email->header('Subject'), qr/Your small items collection is $text - $sutton_id/, "Reminder email for correct service and due $text";
            my $reminder_email_txt = $mech->get_text_body_from_email($email);
            my $reminder_email_html = $mech->get_html_body_from_email($email);
            for my $email ($reminder_email_txt, $reminder_email_html) {
                like $email, qr/Address: 2 Example Street, Sutton, SM2 5HF/, 'Includes collection address';
                like $email, qr/on Friday 08 August/, 'Includes collection date';
                like $email, qr/Items to be collected/, 'Includes Items to be collected section';
                like $email, qr/Batteries/, 'Includes item 1';
                like $email, qr/Small WEEE/, 'Includes item 2';
                like $email, qr#http://sutton.example.org/waste/12345/small_items/cancel/$id#, 'Includes cancellation link';
            };
        }
    };

    subtest 'Cancellation' => sub {
        $report->external_id('Echo-123');
        $report->update;
        my $base_path = '/waste/12345';
        $mech->log_out_ok;

        set_fixed_time('2025-08-08T04:00:00');
        $mech->get_ok($base_path);
        $mech->content_lacks('Cancel booking', 'Logged out user not offered cancellation');
        $mech->get_ok("$base_path/small_items/cancel/" . $report->id);
        $mech->content_contains('Sign in ::', 'Entering cancel link leads to authorisation page');

        set_fixed_time('2025-08-08T07:00:00');
        $mech->log_in_ok($report->user->email);
        $mech->content_lacks('Cancel booking', 'No cancellation after collections started');

        set_fixed_time('2025-08-08T04:00:00');
        for my $email ($report->user->email, $staff->email) {
            $mech->log_in_ok($email);
            $mech->get_ok($base_path);
            $mech->content_contains('Cancel booking', 'Logged in staff/user offered cancellation');
            $mech->get_ok("$base_path/small_items/cancel/" . $report->id);
            $mech->content_lacks('I acknowledge that the collection fee is non-refundable', 'No charge for small items');
            $mech->content_contains('I confirm I wish to cancel my small items collection', 'Must confirm cancellation');
            $mech->submit_form_ok( { with_fields => { confirm => 1 } } );
            $mech->content_contains('Your booking has been cancelled');
            $mech->follow_link_ok( { text => 'Return to property details' } );
            is $mech->uri->path, $base_path, 'Returned to bin days';
            $mech->content_lacks('Cancel booking');

            $report->discard_changes;
            is $report->state, 'cancelled', 'Original report cancelled';
            like $report->detail, qr/Cancelled at user request/, 'Original report detail field updated';
            my $comment = FixMyStreet::DB->resultset('Comment')->find( { problem_id => $report->id } );
            is $comment->text, 'Booking cancelled by customer', 'Comment added';

            subtest 'Viewing original report summary after cancellation' => sub {
                my $id   = $report->id;
                $mech->log_in_ok($report->user->email);
                $mech->get_ok("/report/$id");
                $mech->content_contains('This collection has been cancelled');
                $mech->content_lacks("You can cancel this booking up to");
                $mech->content_lacks('Cancel this booking');
            };

            subtest 'Email received by user' => sub {
                $mech->clear_emails_ok;
                FixMyStreet::Script::Alerts::send_updates();
                like $mech->get_text_body_from_email, qr/Booking cancelled by customer/, 'Booking cancellation email sent';
            };
            # Set report active again
            $report->state('confirmed');
            my $detail = $report->detail;
            $detail =~ s/ \| Cancelled at user request//;
            $report->detail($detail);
            $report->update;
            $comment->delete;
        }
    };

    subtest 'Amending the date' => sub {
        set_fixed_time('2025-08-07T01:00:00');
        my $base_path = '/waste/12345';

        subtest 'Before request sent' => sub {
            $report->external_id(undef);
            $report->update;
            $mech->log_in_ok( $staff->email );
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/small_items/amend/" . $report->id);
            is $mech->uri->path, $base_path, 'Amend link redirects to bin days';
        };

        subtest 'After request sent, normal user cannot amend' => sub {
            $report->external_id('Echo-123');
            $report->update;
            $mech->log_in_ok($report->user->email);
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/small_items/amend/" . $report->id);
            is $mech->uri->path, $base_path;
        };

        subtest 'User logged out' => sub {
            $mech->log_out_ok;
            $mech->get_ok($base_path);
            $mech->content_lacks('Amend booking');
            $mech->get_ok("$base_path/small_items/amend/" . $report->id);
            is $mech->uri->path, $base_path;
        };

        subtest 'Staff user logged in' => sub {
            $mech->log_in_ok( $staff->email );
            $mech->get_ok($base_path);
            $mech->content_contains('href="http://localhost/waste/12345/small_items/amend/' . $report->id . '">Amend booking');
            $mech->get_ok("/report/" . $report->id);
            $mech->content_contains("$base_path/small_items/cancel");
            $mech->content_contains('Cancel this booking');
            $mech->content_contains("$base_path/small_items/amend");
            $mech->content_contains('Amend this booking');
            $mech->get_ok("$base_path/small_items/amend/" . $report->id);
            $mech->content_contains('Amend small items collection');
            $mech->content_contains('Amending your booking');
            is $mech->uri->path, "$base_path/small_items/amend/" . $report->id;
            $mech->submit_form_ok;
            $mech->content_contains('Choose date for collection', "On 'Available dates' page");
            $mech->submit_form_ok( { with_fields => { chosen_date => '2025-08-12T00:00:00;reserve7d==;2025-08-25T10:20:00'}});
            $mech->content_contains('Add items for collection', "On items page");
            $mech->submit_form_ok();
            $mech->content_contains('Location details', "Location page included");
            $mech->submit_form_ok( {form_number  => 2 });
            $mech->content_contains('Booking Summary', "On booking confirmation page");
            $mech->content_contains('action="http://localhost/waste/12345/small_items/amend/' . $report->id);
            $mech->submit_form_ok({form_number => 5, with_fields => { tandc => 1} });
        };
    };

    subtest 'Viewing original report summary after amendment' => sub {
        my $path = "/report/" . $report->id;
        $mech->get_ok($path);
        $mech->content_contains('This collection has been cancelled');
        $mech->content_contains('Booking cancelled due to amendment');
        $report->discard_changes;
        is $report->state, 'cancelled';
    };

    $report = FixMyStreet::DB->resultset("Problem")->search({ title => 'Small items collection' })->order_by('-id')->first;
    subtest 'New report details' => sub {
        like $report->detail, qr/Previously submitted as/, 'Original report detail field updated';
        is $report->category, 'Small items collection';
        is $report->title, 'Small items collection';
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Collection_Date_-_Bulky_Items'), '2025-08-12T00:00:00';
        is $report->get_extra_field_value('Small_Item_Type'), '1::2';
        is $report->get_extra_field_value('property_id'), '12345';
        is $report->get_extra_field_value('GUID'), '4ea70923-7151-11f0-aeea-cd51f3977c8c';
        is $report->get_extra_field_value('reservation'), 'reserve7d==';
        is $report->photo, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';
    };

    subtest 'Reporting a missed collection' => sub {

        # Monday after collection was due
        set_fixed_time('2025-08-11T12:00:00Z');

        # Event claims it was completed
        $echo->mock(
            'GetEventsForObject',
            sub {
                [   {   Guid        => '4ea70923-7151-11f0-aeea-cd51f3977c8c',
                        EventTypeId => 3144,
                        ResolvedDate =>
                            { DateTime => '2025-08-08T12:00:00Z' },
                        EventDate => { DateTime => '2025-08-08T12:00:00Z' },
                        ResolutionCodeId => 232,
                        EventStateId     => 12400,
                    }
                ]
            }
        );

        $report->update(
            {   state       => 'fixed - council',
                external_id => '4ea70923-7151-11f0-aeea-cd51f3977c8c'
            }
        );

        $mech->get_ok('/waste/12345');
        $mech->content_contains('Report a small items collection as missed');
        $mech->submit_form_ok( { form_number => 1 },
            "Follow link for reporting a missed collection" );
        $mech->content_contains('Select your missed collection');
        $mech->submit_form_ok( { with_fields => { 'service-952' => 1 } } );
        $mech->content_contains('Please supply any additional information');
        $mech->submit_form_ok(
            { with_fields => { extra_detail => 'You left a sock' } } );
        $mech->content_contains('About you');
        $mech->submit_form_ok(
            { with_fields => { name => 'Mary Kay', email => $user->email } }
        );
        $mech->content_contains('Submit missed small items collection');
        $mech->submit_form_ok( { form_number => 3 } );
        $mech->content_contains(
            'Thank you for reporting a missed collection');

        my $missed
            = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $missed->get_extra_field_value('Exact_Location'), 'In the alley';
        is $missed->title, 'Report missed small items collection';
        is $missed->get_extra_field_value('Original_Event_ID'),
            '4ea70923-7151-11f0-aeea-cd51f3977c8c';
        is $missed->get_extra_field_value('Notes'), 'You left a sock';

        $missed->update(
            { external_id => '8d222528-4308-44c3-9981-ea6131a6b00f' } );
        $echo->mock(
            'GetEventsForObject',
            sub {
                [
                    # Event for original report
                    {   Guid        => '4ea70923-7151-11f0-aeea-cd51f3977c8c',
                        EventTypeId => 3144,
                        ResolvedDate =>
                            { DateTime => '2025-08-08T12:00:00Z' },
                        EventDate => { DateTime => '2025-08-08T12:00:00Z' },
                        ResolutionCodeId => 232,
                        EventStateId     => 12400,
                    },
                    # Event for missed collection
                    {   Guid        => '8d222528-4308-44c3-9981-ea6131a6b00f',
                        EventTypeId => 3145,
                        EventStateId => 0,
                        ServiceId    => 952,
                        EventDate => { DateTime => '2025-08-11T12:00:00Z' },
                    },
                ]
            }
        );

        $mech->get_ok('/waste/12345');
        $mech->text_contains(
            'A small items collection was reported as missed on Monday, 11 August'
        );

        # subtest 'Assisted collection' => sub {};
    };

};

done_testing;
