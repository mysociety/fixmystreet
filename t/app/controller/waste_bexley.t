use Test::Deep;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;
use t::Mock::Bexley;

set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST

my $mech = FixMyStreet::TestMech->new;

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Bexley');
$mock->mock('_fetch_features', sub { [] });

my $whitespace_mock = $bexley_mocks{whitespace};

my $comment_user = $mech->create_user_ok('comment', name => 'London Borough of Bexley', email => 'bexley@example.org', email_verified => 1);
my $user = $mech->create_user_ok('test@example.com', name => 'Test User', email_verified => 1);
my $body = $mech->create_body_ok(
    2494,
    'London Borough of Bexley',
    {
        comment_user           => $comment_user,
        send_extended_statuses => 1,
        can_be_devolved        => 1,
        cobrand => 'bexley'
    },
);
my $contact = $mech->create_contact_ok(
    body => $body,
    category => 'Report missed collection',
    email => 'missed@example.org',
    extra => { type => 'waste' },
    group => ['Waste'],
);
my $staff = $mech->create_user_ok('staff@example.com', name => 'Test User', email_verified => 1, from_body => $body);


$contact->set_extra_fields(
    {
        code => "uprn",
        required => "false",
        automated => "hidden_field",
        description => "UPRN reference",
    },
    {
        code => "service_item_name",
        required => "false",
        automated => "hidden_field",
        description => "Service item name",
    },
    {
        code => "fixmystreet_id",
        required => "true",
        automated => "server_set",
        description => "external system ID",
    },
    {
        code => "assisted_yn",
        required => "false",
        automated => "hidden_field",
        description => "Assisted collection (Yes/No)",
    },
    {
        code => "location_of_containers",
        required => "false",
        automated => "hidden_field",
        description => "Location of containers",
    }
);

$contact->update;

my $contact2 = $mech->create_contact_ok(
    body => $body,
    category => 'Missed collection enquiry',
    email => 'waste-enquiry@example.org',
    extra => { type => 'waste' },
    group => ['Waste'],
    send_method => 'Email::Bexley',
);
$contact2->set_extra_fields(
    {
        code => "waste_types",
        description => "Which collections would you like to report as missed?",
        datatype => "multivaluelist",
        required => "true",
        values => [
            map { { key => $_, name => $_ } } (
                "Refuse",
                "Paper/card recycling",
                "Plastics/glass recycling",
                "Food waste",
                "Garden waste",
                "Mixed recycling"
            )
        ],
    }
);
$contact2->update;

my $contact3 = $mech->create_contact_ok(
    body => $body,
    category => 'Replacement bin enquiry',
    email => 'waste-enquiry@example.org',
    extra => { type => 'waste' },
    group => ['Waste'],
    send_method => 'Email::Bexley',
);
$contact3->set_extra_fields(
    { code => 'uprn', automated => "hidden_field" },
    { code => 'complaint_type', automated => "hidden_field" },
    {
        code => "Container",
        description => "Which container(s) do you require?",
        datatype => "multivaluelist",
        required => "true",
        values => [
            map { { key => $_, name => $_ } } (
                'Non-recyclable waste',
                'Paper/card recycling',
                'Plastic, can and glass recycling',
                'Food waste',
            )
        ],
    }
);
$contact3->update;

my $assisted_collection = $mech->create_contact_ok(
    body => $body,
    category => 'Request assisted collection',
    email => 'assisted@example.org',
    extra => { type => 'waste' },
    group => ['Waste'],
);

$assisted_collection->set_extra_fields(
    {
        code => "uprn",
        required => "false",
        automated => "hidden_field",
        description => "UPRN reference",
    },
    {
        code => "fixmystreet_id",
        required => "true",
        automated => "server_set",
        description => "external system ID",
    },
    {
        code => "reason_for_collection",
        required => "true",
        datatype => "singlevaluelist",
        description => "Why do you need an extra collection?",
        values => [
            map { { key => $_, name => $_ } } (
                "Property is unsuitable for collections from the front boundary",
                "Physical impairment/Elderly resident"
            )
        ],
    },
    {
        code => "bin_location",
        required => "true",
        datatype => "text",
        description => "Where are the bins located?",
    },
    {
        code => "permanent_or_temporary_help",
        required => "true",
        datatype => "singlevaluelist",
        description => "Is this request for permanent or temporary help?",
        values => [
            map { { key => $_, name => $_ } } (
                'Permanent',
                'Temporary'
            )
        ],
    },
    {
        code => "assisted_staff_notes",
        required => "false",
        datatype => "textarea",
        description => "Staff notes",
    },
);
$assisted_collection->update;

my $assisted_collection_approval = $mech->create_contact_ok(
    body => $body,
    category => 'Assisted collection add',
    email => 'assisted_collection',
    send_method => 'Open311',
    extra => { type => 'waste' },
    group => ['Waste'],
);

$assisted_collection_approval->set_extra_fields(
    {
        code => "uprn",
        required => "false",
        automated => "hidden_field",
        description => "UPRN reference",
    },
    {
        code => "fixmystreet_id",
        required => "true",
        automated => "server_set",
        description => "external system ID",
    },
    {
        code => "assisted_reason",
        required => "true",
        datatype => "singlevaluelist",
        description => "Why do you need an extra collection?",
        values => [
            map { { key => $_, name => $_ } } (
                "physical",
                "property"
            )
        ],
    },
    {
        code => "assisted_location",
        required => "true",
        datatype => "text",
        description => "Where are the bins located?",
    },
    {
        code => "assisted_duration",
        required => "true",
        datatype => "singlevaluelist",
        description => "Is this request for permanent or temporary help?",
        values => [
            map { { key => $_, name => $_ } } (
                '3 Months',
                '6 Months',
                '12 Months',
                'No End Date',
            )
        ],
    }
);
$assisted_collection_approval->update;

my ($existing_missed_collection_report1) = $mech->create_problems_for_body(1, $body->id, 'Report missed collection', {
    external_id => "Whitespace-4",
});
$existing_missed_collection_report1->set_extra_fields(
    { name => 'service_item_name', value => 'PC-55' } );
$existing_missed_collection_report1->update;

my ($existing_missed_collection_report2) = $mech->create_problems_for_body(1, $body->id, 'Report missed collection', {
    external_id => "Whitespace-5",
});
$existing_missed_collection_report2->set_extra_fields(
    { name => 'service_item_name', value => 'PA-55' } );
$existing_missed_collection_report2->update;
$existing_missed_collection_report2->add_to_comments(
    {
        external_id   => $existing_missed_collection_report2->external_id,
        problem_state => $existing_missed_collection_report2->state,
        text          => 'Preexisting comment',
        user          => $comment_user,
    }
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        whitespace => { bexley => { url => 'http://example.org/' } },
        agile => { bexley => { url => 'test' } },
        waste => { bexley => 1 },
        waste_calendar_links => { bexley =>  { 'Wk-1' => 'PDF 1', 'Wk-2' => 'PDF 2'} },
    },
}, sub {
    subtest 'Postcode search page is shown' => sub {
        $mech->get_ok('/waste');
        $mech->content_contains('Bins, rubbish and recycling');
        $mech->content_contains('Find your bin collection days');
        $mech->content_contains('Report a missed bin collection');
        $mech->content_lacks('Order new or additional bins');
    };

    subtest 'False postcode shows error' => sub {
        $mech->submit_form_ok( { with_fields => { postcode => 'PC1 1PC' } } );
        $mech->content_contains('Sorry, we did not recognise that postcode');
    };

    subtest 'Postcode with multiple addresses progresses to selecting an address' => sub {
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 3LD' } } );
        $mech->content_contains('Select an address');
        $mech->content_contains('<option value="10001">1 The Avenue</option>');
        $mech->content_contains('<option value="10002">2 The Avenue</option>');
    };

    subtest 'Postcode with one address progresses to selecting an address' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 3NP' } } );
        $mech->content_contains('Select an address');
        $mech->content_contains(
            '<option value="10001">Flat, 98a-99b The Court, 1a-2b The Avenue, Little Bexlington, Bexley</option>'
        );
    };

    subtest 'Correct services are shown for address' => sub {
        $mech->submit_form_ok( { with_fields => { address => 10001 } } );

        test_services($mech);
        $mech->content_contains("You do not have a Garden waste collection");

        $mech->content_contains(
            '<dd class="waste__address__property">Flat, 98a-99b The Court, 1a-2b The Avenue, Little Bexlington, Bexley, DA1 3NP</dd>',
            'Correct address string displayed',
        );
        $mech->content_contains(
            'Your collection schedule is Week 2',
            'Correct rotation schedule displayed',
        );

        note 'Missed collection displays';
        $mech->content_contains(
            'A blue recycling box collection has already been reported as missed');
        $mech->content_contains('Reported on: N/A');
        $mech->content_contains('Will be completed by: N/A');
        $mech->content_contains('Action: Please leave your waste out, our contractor will return soon');

        $mech->content_contains(
            'A green recycling box collection has already been reported as missed');
        $mech->content_contains('Action: Preexisting comment');

        subtest 'service_sort sorts correctly' => sub {
            my $cobrand = FixMyStreet::Cobrand::Bexley->new;
            $cobrand->{c} = Test::MockObject->new;

            my %session_hash;
            $cobrand->{c}->mock( session => sub { \%session_hash } );
            $cobrand->{c}->mock( waste_cache_get => sub {
                Catalyst::Plugin::FixMyStreet::Session::WasteCache::waste_cache_get(@_);
            });
            $cobrand->{c}->mock( waste_cache_set => sub {
                Catalyst::Plugin::FixMyStreet::Session::WasteCache::waste_cache_set(@_);
            });

            my $log = Test::MockObject->new;
            $log->mock( info => sub {} );
            $cobrand->{c}->mock( log => sub { $log } );
            $cobrand->{c}->mock( stash => sub { {} } );
            $cobrand->{c}->mock( cobrand => sub { $cobrand });
            $cobrand->{c}->mock( action => sub { "" } );

            my @sorted = $cobrand->service_sort(
                @{  $cobrand->bin_services_for_address(
                        { uprn => 10001, usrn => 321 }
                    )
                }
            );
            my %defaults = (
                service_description_contains_html => undef,
                next => {
                    changed => 0,
                    ordinal => ignore(),
                    date => ignore(),
                    is_today => ignore(),
                    already_collected => 0,
                },
                last => {
                    ordinal => ignore(),
                    date => ignore(),
                },
                uprn => ignore(),
                garden_waste => 0,
            );
            my %nolast = %defaults;
            delete $nolast{last};
            cmp_deeply \@sorted, [
                {   id             => 8,
                    service_id     => 'PC-55',
                    service_name   => 'Blue Recycling Box',
                    service_description => 'Paper and card',
                    round_schedule => 'RND-8-9 Mon, RND-8-9 Wed',
                    round          => 'RND-8-9',
                    report_allowed => 0,
                    delivery_open  => 0,
                    removal_open   => 0,
                    report_open    => 1,
                    report_details => {
                        id                => ignore(),
                        external_id       => 'Whitespace-4',
                        open              => 1,
                        reported          => '',
                        will_be_completed => '',
                        latest_comment    => '',
                    },
                    report_locked_out => 0,
                    report_locked_out_reason => '',
                    assisted_collection => 1, # Has taken precedence over PC-55 non-assisted collection
                    schedule => 'Twice Weekly',
                    %defaults,
                },
                {   id             => 9,
                    service_id     => 'PA-55',
                    service_name   => 'Green Recycling Box',
                    service_description => 'Paper and card',
                    round_schedule => 'RND-8-9 Mon, RND-8-9 Wed',
                    round          => 'RND-8-9',
                    report_allowed => 0,
                    delivery_open  => 0,
                    removal_open   => 0,
                    report_open    => 1,
                    report_details => {
                        id                => ignore(),
                        external_id       => 'Whitespace-5',
                        open              => 1,
                        reported          => '2024-03-31T01:00:00',
                        will_be_completed => '2024-04-02T01:00:00',
                        latest_comment    => 'Preexisting comment',
                    },
                    report_locked_out => 0,
                    report_locked_out_reason => '',
                    assisted_collection => 0,
                    schedule => 'Twice Weekly',
                    %defaults,
                },
                {   id             => 1,
                    service_id     => 'FO-140',
                    service_name   => 'Communal Food Bin',
                    service_description => 'Food waste',
                    round_schedule => 'RND-1 Tue Wk 2',
                    round          => 'RND-1',
                    report_allowed => 0,
                    delivery_open  => 0,
                    removal_open   => 0,
                    report_open    => 0,
                    report_locked_out => 1,
                    report_locked_out_reason => 'Food - Not Out',
                    assisted_collection => 0,
                    schedule => 'Fortnightly',
                    %defaults,
                },
                {   id             => 7,
                    delivery_allowed => 1,
                    parent_name => 'Blue Lidded Wheelie Bin',
                    removal_allowed => 1,
                    service_id     => 'PC-180',
                    service_name   => 'Blue Lidded Wheelie Bin',
                    service_description => 'Paper and card',
                    round_schedule => 'N/A',
                    round          => 'N/A',
                    report_allowed => 0,
                    delivery_open  => 0,
                    removal_open   => 0,
                    report_open    => 0,
                    report_locked_out => 0,
                    report_locked_out_reason => '',
                    assisted_collection => 0,
                    schedule => 'Weekly',
                    %nolast,
                },
                {   id             => 6,
                    service_id     => 'RES-CHAM',
                    service_name   => 'Communal Refuse Bin(s)',
                    service_description => 'Non-recyclable waste',
                    round_schedule => 'RND-6 Wed Wk 2',
                    round          => 'RND-6',
                    report_allowed => 1,
                    delivery_open  => 0,
                    removal_open   => 0,
                    report_open    => 0,
                    report_locked_out => 0,
                    report_locked_out_reason => '',
                    assisted_collection => 0,
                    schedule => 'Fortnightly',
                    %defaults,
                },
                {   id             => 10,
                    service_id     => 'PL-940',
                    service_name   => 'White / Silver Recycling Bin',
                    service_description => 'Plastics and cans',
                    round_schedule => 'RND-6 Wed Wk 2',
                    round          => 'RND-6',
                    report_allowed => 1,
                    delivery_open  => 0,
                    removal_open   => 0,
                    report_open    => 0,
                    report_locked_out => 0,
                    report_locked_out_reason => '',
                    assisted_collection => 0,
                    schedule => 'Fortnightly',
                    %defaults,
                },
            ];

            my %expected_last_dates = (
                8  => '2024-03-28T00:00:00',
                9  => '2024-03-28T00:00:00',
                1  => '2024-03-24T00:00:00',
                6  => '2024-03-27T00:00:00',
                10 => '2024-03-27T00:00:00',
            );
            for (@sorted) {
                is $_->{last}{date}, $expected_last_dates{ $_->{id} };
            }
        };
    };

    subtest 'Parent services shown for child' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 3LD' } } );
        $mech->submit_form_ok( { with_fields => { address => 10002 } } );

        test_services($mech);
        $mech->content_lacks("You do not have a Garden waste collection"); # not allowed GGW if communal property
    };

    sub test_services {
        my $mech = shift;

        $mech->content_contains('Communal Food Bin');
        $mech->content_contains('Tuesday 30 April 2024');
        $mech->content_lacks('Brown Caddy');
        $mech->content_lacks('Green Recycling Bin');
        $mech->content_lacks('Black Recycling Box');
        $mech->content_contains('Communal Refuse Bin(s)');
        $mech->content_contains('Wednesday 1 May 2024');
        $mech->content_contains('White / Silver Recycling Bin');
        $mech->content_contains('Wednesday 1 May 2024');
        $mech->content_contains('Blue Lidded Wheelie Bin');
        $mech->content_contains('Blue Recycling Box');
        $mech->content_contains('Monday 1 April 2024');
        $mech->content_contains('Green Recycling Box');
        $mech->content_contains('Monday 1 April 2024');
    }

    subtest 'Checking calendar' => sub {
        $mech->follow_link_ok({ text => 'Add to your calendar' });
        $mech->follow_link_ok({ text_regex => qr/this link/ });
        $mech->content_contains('BEGIN:VCALENDAR');
        my @events = split /BEGIN:VEVENT/, $mech->encoded_content;
        shift @events; # Header

        my $expected_num = 24;
        is @events, $expected_num, "$expected_num events in calendar";

        my $i = 0;
        for (@events) {
            $i++ if /DTSTART;VALUE=DATE:20240401/ && /SUMMARY:Blue Recycling Box \(Paper and card\)/;
            $i++ if /DTSTART;VALUE=DATE:20240401/ && /SUMMARY:Green Recycling Box \(Paper and card\)/;
            $i++ if /DTSTART;VALUE=DATE:20240402/ && /SUMMARY:Communal Food Bin \(Food waste\)/;
            $i++ if /DTSTART;VALUE=DATE:20240403/ && /SUMMARY:Communal Refuse Bin\(s\) \(Non-recyclable waste\)/;
            $i++ if /DTSTART;VALUE=DATE:20240403/ && /SUMMARY:White \/ Silver Recycling Bin \(Plastics and cans\)/;
            $i++ if /DTSTART;VALUE=DATE:20240403/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240403/ && /SUMMARY:Green Recycling Box/;

            $i++ if /DTSTART;VALUE=DATE:20240408/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240408/ && /SUMMARY:Green Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240410/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240410/ && /SUMMARY:Green Recycling Box/;

            $i++ if /DTSTART;VALUE=DATE:20240415/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240415/ && /SUMMARY:Green Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240416/ && /SUMMARY:Communal Food Bin/;
            $i++ if /DTSTART;VALUE=DATE:20240417/ && /SUMMARY:Communal Refuse Bin\(s\)/;
            $i++ if /DTSTART;VALUE=DATE:20240417/ && /SUMMARY:White \/ Silver Recycling Bin/;
            $i++ if /DTSTART;VALUE=DATE:20240417/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240417/ && /SUMMARY:Green Recycling Box/;

            $i++ if /DTSTART;VALUE=DATE:20240501/ && /SUMMARY:Communal Refuse Bin\(s\)/;
            $i++ if /DTSTART;VALUE=DATE:20240501/ && /SUMMARY:White \/ Silver Recycling Bin/;

            $i++ if /DTSTART;VALUE=DATE:20240506/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240506/ && /SUMMARY:Green Recycling Box/;

            $i++ if /DTSTART;VALUE=DATE:20240515/ && /SUMMARY:Communal Refuse Bin\(s\)/;
            $i++ if /DTSTART;VALUE=DATE:20240515/ && /SUMMARY:White \/ Silver Recycling Bin/;
        }
        is $i, $expected_num, 'Correct events in the calendar';
    };

    subtest 'Correct PDF download link shown' => sub {
        for my $test ({ address => 10003, link => 1 }, { address => 10004, link => 2 }) {
            $mech->get_ok('/waste');
            $mech->submit_form_ok( { with_fields => { postcode => 'DA1 3LD' } } );
            $mech->submit_form_ok( { with_fields => { address => $test->{address} } } );
            $mech->content_contains(
                "Your collection schedule is Week $test->{link}",
                'Correct rotation schedule displayed',
            );
            $mech->content_contains('<li><a target="_blank" href="PDF '. $test->{link} . '">View and download collection calendar', 'PDF link ' . $test->{link} . ' shown');
        }
    };

    subtest 'Various logs for today' => sub {
        $whitespace_mock->mock( 'GetSiteCollections', sub {
            return [
                {   SiteServiceID          => 8,
                    ServiceItemDescription => 'Service 8',
                    ServiceItemName      => 'PC-55',  # Blue Recycling Box
                    ServiceName          => 'Blue Recycling Box',
                    NextCollectionDate   => '2024-04-01T00:00:00',
                    SiteServiceValidFrom => '2024-03-31T00:59:59',
                    SiteServiceValidTo   => '0001-01-01T00:00:00',

                    RoundSchedule => 'RND-8-9 Mon, RND-8-9 Wed',
                },
                {   SiteServiceID          => 6,
                    ServiceItemDescription => 'Service 6',
                    ServiceItemName => 'RES-CHAM', # Residual Chamberlain

                    NextCollectionDate   => '2024-05-01T00:00:00',
                    SiteServiceValidFrom => '2024-03-31T00:59:59',
                    SiteServiceValidTo   => '0001-01-01T00:00:00',

                    RoundSchedule => 'RND-6 Wed Wk 2',
                },
            ];
        } );
        $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub { [] } );

        set_fixed_time('2024-04-01T07:00:00'); # April 1st, 08:00 BST

        note 'No in-cab logs';
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Service status');
        $mech->content_contains('Being collected today');
        $mech->content_lacks('Reported as collected today');
        $mech->content_lacks('Could not be collected today because it was red-tagged. See reason below.');
        $mech->content_contains('Please note that missed collections can only be reported within 3 working days of your last collection day');

        # Set time to later in the day
        set_fixed_time('2024-04-01T16:01:00'); # April 1st, 17:01 BST

        note 'Successful collection has occurred';
        $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub {
            return [
                {
                    LogID => 1,
                    Reason => 'N/A',
                    RoundCode => 'RND-8-9',
                    LogDate => '2024-04-01T12:00:00.417',
                    Uprn => '',
                    Usrn => '321',
                },
            ];
        });
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Service status');
        $mech->content_lacks('Being collected today');
        $mech->content_contains('Reported as collected today');
        $mech->content_lacks('Could not be collected today because it was red-tagged. See reason below.');

        note 'Property has red tag on collection attempted earlier today';
        $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub {
            return [
                {
                    LogID => 1,
                    Reason => 'Paper & Card - Bin has gone feral',
                    RoundCode => 'RND-8-9',
                    LogDate => '2024-04-01T12:00:00.417',
                    Uprn => '10001',
                    Usrn => '321',
                },
            ];
        });
        $mech->get_ok('/waste/10001');
        $mech->content_contains('Service status');
        $mech->content_contains(
            'Our collection teams have reported the following problems with your bins:'
        );
        $mech->content_lacks('Being collected today');
        $mech->content_lacks('Reported as collected today');
        $mech->content_contains('Could not be collected today because it was red-tagged. See reason below.');

        note 'Property has collection but also manual red tag';
        $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub {
            return [
                {
                    LogID => 1,
                    Reason => 'N/A',
                    RoundCode => 'RND-8-9',
                    LogDate => '2024-04-01T12:00:00.417',
                    Uprn => '',
                    Usrn => '321',
                },
                {
                    LogID => 2,
                    Reason => 'Paper & Card - Bin has gone feral',
                    RoundCode => '(Mon) RND-8-9',
                    LogDate => '2024-04-01T12:00:00.417',
                    Uprn => '10001',
                    Usrn => '321',
                },
            ];
        });
        $mech->get_ok('/waste/10001');
        $mech->content_contains('Could not be collected today because it was red-tagged. See reason below.');

        note 'Red tag on other property on same street';
        $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub {
            return [
                {
                    LogID => 1,
                    Reason => 'Paper & Card - Bin has gone feral',
                    RoundCode => 'RND-8-9',
                    LogDate => '2024-04-01T12:00:00.417',
                    Uprn => '19991',
                    Usrn => '321',
                },
            ];
        });
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Service status');
        $mech->content_lacks('Being collected today');
        $mech->content_contains('Reported as collected today');
        $mech->content_lacks('Could not be collected today because it was red-tagged. See reason below.');

        # Reinstate original mocks
        set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST
        default_mocks();
    };

    subtest 'Asks user for location of bins on missed collection form' => sub {
        subtest 'when not staff, assisted, communal, or above shop' => sub {
            $whitespace_mock->mock(
                'GetSiteCollections',
                sub {
                    [   {   SiteServiceID          => 8,
                            ServiceItemDescription => 'Service 8',
                            ServiceItemName => 'PC-55',   # Blue Recycling Box
                            ServiceName          => 'Blue Recycling Box',
                            NextCollectionDate   => '2024-04-01T00:00:00',
                            SiteServiceValidFrom => '2024-03-31T00:59:59',
                            SiteServiceValidTo   => '0001-01-01T00:00:00',

                            RoundSchedule => 'RND-8-9 Mon, RND-8-9 Wed',
                        },
                    ];
                }
            );


            $mech->get_ok('/waste/10001/report');
            $mech->content_contains(
                '<input type="hidden" name="bin_location" id="bin_location" value="Front of property">',
                'Hidden location field has default value'
            );

            # Original mock
            default_mocks();
        };

        $mech->get_ok('/waste/10001/report');
        $mech->content_contains('Bin location');
        $mech->content_contains('name="bin_location"');
        $mech->content_contains($_)
            for
            @{ FixMyStreet::Cobrand::Bexley::Waste::_bin_location_options()
                ->{staff_or_assisted} };

        $mech->get_ok('/waste/10002/report');
        $mech->content_contains('Bin location');
        $mech->content_contains('name="bin_location"');
        $mech->content_contains($_)
            for
            @{ FixMyStreet::Cobrand::Bexley::Waste::_bin_location_options()
                ->{communal} };
    };

    subtest 'Correct labels used when reporting missed collection' => sub {
        $mech->get_ok('/waste/10001/report');
        $mech->content_contains('Non-recyclable waste', 'includes service description in the checkbox label');
    };

    subtest 'Making a missed collection report' => sub {
        $mech->delete_problems_for_body( $body->id );

        $mech->get_ok('/waste/10001/report');
        $mech->submit_form_ok(
            {   with_fields => {
                    bin_location       => 'Front boundary of property',
                    'service-RES-CHAM' => 1,
                    'service-PL-940'   => 1,
                }
            },
            'Selecting missed collection for multiple container types',
        );
        $mech->submit_form_ok(
            { with_fields => { name => 'John Doe', phone => '44 07 111 111 111', email => 'test@example.com' } },
            'Submitting contact details');
        $mech->submit_form_ok(
            { with_fields => { submit => 'Report collection as missed', category => 'Report missed collection' } },
            'Submitting missed collection report');

        $mech->content_contains('Thank you for reporting a missed collection');
        for (
            'Communal Refuse Bin(s) (Non-recyclable waste)',
            'White / Silver Recycling Bin (Plastics and cans)'
            )
        {
            $mech->content_contains( "<li>$_</li>", 'Bin type displayed' );
        }
        $mech->content_contains( 'Flat, 98a-99b The Court, 1a-2b The Avenue, Little Bexlington, Bexley, DA1 3NP', 'Address displayed' );
        $mech->content_contains(
            'Our waste contractor will return',
            'Additional message displayed',
        );

        my $rows = FixMyStreet::DB->resultset("Problem")->order_by('id');
        my @service_item_names;
        while ( my $report = $rows->next ) {
            ok $report->confirmed;
            is $report->state, 'confirmed';
            is $report->get_extra_field_value('uprn'), '10001', 'UPRN is correct';
            is $report->get_extra_field_value('assisted_yn'), 'Yes', 'Assisted collection is correct';
            is $report->get_extra_field_value('location_of_containers'), 'Front boundary of property', 'Location of containers is correct';
            push @service_item_names, $report->get_extra_field_value('service_item_name');
        }
        cmp_deeply \@service_item_names,
            [ 'PL-940', 'RES-CHAM' ],
            'Service item names are correct';
    };

    subtest 'Missed collection reports are made against the parent property' => sub {
        $mech->get_ok('/waste/10002/report');
        $mech->submit_form_ok(
            { with_fields => { bin_location => 'Rear of property', 'service-RES-CHAM' => 1 } },
            'Selecting missed collection for communal refuse bin');
        $mech->submit_form_ok(
            { with_fields => { name => 'John Doe', phone => '44 07 111 111 111', email => 'test@example.com' } },
            'Submitting contact details');
        $mech->submit_form_ok(
            { with_fields => { submit => 'Report collection as missed', category => 'Report missed collection' } },
            'Submitting missed collection report');

        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;

        is $report->get_extra_field_value('uprn'), '10001', 'Report is against the parent property';
    };

    subtest 'Make sure missed collection cannot be made against ineligible container when page is not refreshed'
    => sub {

        $mech->delete_problems_for_body( $body->id );

        # Thursday 4th April, 13:00 BST
        set_fixed_time('2024-04-04T12:00:00');

        $whitespace_mock->mock(
            'GetSiteCollections',
            sub {
                [   {   SiteServiceID          => 1,
                        ServiceItemDescription => 'Service 1',
                        ServiceItemName => 'FO-140',    # Communal Food Bin

                        NextCollectionDate   => '2024-04-08T00:00:00',
                        SiteServiceValidFrom => '2024-03-31T00:59:59',
                        SiteServiceValidTo   => '0001-01-01T00:00:00',

                        RoundSchedule => 'RND-1 Mon',
                    },
                    {   SiteServiceID          => 2,
                        ServiceItemDescription => 'Service 2',
                        ServiceItemName        => 'FO-23',       # Brown Caddy

                        NextCollectionDate   => '2024-04-10T00:00:00',
                        SiteServiceValidFrom => '2024-03-31T00:59:59',
                        SiteServiceValidTo   => '0001-01-01T00:00:00',

                        RoundSchedule => 'RND-2 Wed',
                    },
                ];
            }
        );
        $whitespace_mock->mock(
            'GetCollectionByUprnAndDatePlus',
            sub {
                [   {   Date     => '01/04/2024 00:00:00', # Mon
                        Round    => 'RND-1',
                        Schedule => 'Mon',
                        Service  => 'Service 1 Collection',
                    },
                    {   Date     => '03/04/2024 00:00:00', # Wed
                        Round    => 'RND-2',
                        Schedule => 'Wed',
                        Service  => 'Service 2 Collection',
                    },
                ];
            }
        );
        $whitespace_mock->mock(
            'GetInCabLogsByUsrn',
            sub {
                [
                    {
                        Reason => 'N/A',
                        RoundCode => 'RND-1',
                        LogDate => '2024-04-01T06:10:09.417', # Mon
                        Uprn => '',
                        Usrn => '321',
                    },
                    {
                        Reason => 'N/A',
                        RoundCode => 'RND-2',
                        LogDate => '2024-04-03T06:10:09.417', # Wed
                        Uprn => '',
                        Usrn => '321',
                    },
                ]
            }
        );

        $mech->get_ok('/waste/10001');

        # Check for presence of two missed collection links
        $mech->content_contains('Report a communal food bin collection as missed');
        $mech->content_contains('Report a brown caddy collection as missed');
        $mech->content_unlike(
            qr/id="service-FO-23-0".*checked/s,
            'Brown caddy not preselected',
        );

        # Friday 5th April, 13:00 BST
        set_fixed_time('2024-04-05T12:00:00');

        $mech->submit_form( form_name => 'FO-140-missed' );

        $mech->content_contains('Select your missed collection');
        $mech->content_lacks( 'name="service-FO-140"',
            'Communal food bin checkbox not shown' );
        $mech->content_contains( 'name="service-FO-23"',
            'Brown caddy checkbox shown' );

        $mech->submit_form_ok(
            {   with_fields => {
                    'service-FO-23' => 1
                }
            },
            'Selecting missed collection for brown caddy',
        );
        $mech->submit_form_ok(
            {   with_fields => {
                    name  => 'John Doe',
                    phone => '44 07 111 111 111',
                    email => 'test@example.com'
                }
            },
            'Submitting contact details'
        );
        $mech->submit_form_ok(
            {   with_fields => {
                    submit   => 'Report collection as missed',
                    category => 'Report missed collection'
                }
            },
            'Submitting missed collection report'
        );
        $mech->content_contains('Thank you for reporting a missed collection');
        $mech->content_contains( '<li>Brown Caddy (Food waste)</li>', 'Bin type displayed' );

        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $email;
        for my $mail (@emails) {
            $email = $mail->as_string if $mail->header('To') =~ 'test@example.com';
        };
        like $email, qr/Brown Caddy \(Food waste\)/, 'Service added to title';
        my @reports = FixMyStreet::DB->resultset("Problem")->all;
        is @reports, 1, 'only one report created';

        # Check that if eligible link followed, service is
        # pre-selected
        $mech->get_ok('/waste/10001');
        $mech->submit_form( form_name => 'FO-23-missed' );
        $mech->content_like(
            qr/id="service-FO-23-0".*checked/s,
            'Brown caddy preselected',
        );

        # Reset
        set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST
        $mech->delete_problems_for_body( $body->id );
        default_mocks();
    };

    subtest 'Missed collection eligibility checks' => sub {
        set_fixed_time('2024-04-22T12:00:00'); # Monday

        my %services = (
            # Has a missed collection report
            'RES-SACK' => {
                service_id => 'RES-SACK',
                round => 'RES-R1',
                round_schedule => 'RES-R1 Fri',
            },
            # Has exception against round
            'MDR-SACK' => {
                service_id => 'MDR-SACK',
                round => 'MDR-R1',
                round_schedule => 'MDR-R1 Fri',
            },
            # Collection due today but has not happened
            'FO-23' => {
                service_id => 'FO-23',
                round => 'RCY-R1',
                round_schedule => 'RCY-R1 Mon',
                next => {
                    is_today => 1,
                },
                last => {
                    date => DateTime->today,
                }
            },
            # Had a collection earlier today
            'FO-140' => {
                service_id => 'FO-140',
                round => 'RCY-R2',
                round_schedule => 'RCY-R2 Mon',
                next => {
                    is_today => 1,
                },
                last => {
                    date => DateTime->today,
                },
            },
            # Collection due last working day but it did not happen
            'RES-180' => {
                service_id => 'RES-180',
                round => 'RES-R2',
                round_schedule => 'RES-R2 Fri',
                last => {
                    date => DateTime->today->subtract( days => 3 ),
                },
            },
            # Collections due last working day and they happened
            'RES-240' => {
                service_id => 'RES-240',
                round => 'RES-R3',
                round_schedule => 'RES-R3 Fri',
                last => {
                    date => DateTime->today->subtract( days => 3 ),
                },
            },
            'RES-660' => {
                service_id => 'RES-660',
                round => 'RES-R4',
                round_schedule => 'RES-R4 Fri',
                last => {
                    date => DateTime->today->subtract( days => 3 ),
                },
            },
            # Collection too old
            'GA-240' => {
                service_id => 'GA-240',
                round => 'GDN-R1',
                round_schedule => 'GDN-R1 Tue',
                last => {
                    date => DateTime->today->subtract( days => 6 ),
                },
            },
            'PG-240' => {
                service_id => 'PG-240',
                round => 'RCY-R2',
                round_schedule => 'RCY-R2 Mon PG Wk 2',
                last => {
                    date => DateTime->today->subtract( days => 7 ),
                },
            },
        );

        my $property = {
            uprn => 10001,
            missed_collection_reports => {
                'RES-SACK' => 1,
            },
        };

        my $cobrand = FixMyStreet::Cobrand::Bexley->new;
        $cobrand->{c} = Test::MockObject->new;
        $cobrand->{c}->mock(
            stash => sub {
                {
                    cab_logs => [
                        # Successful collection today
                        {   LogDate   => '2024-04-22T10:00:00.977',
                            Reason    => 'N/A',
                            RoundCode => 'RCY-R2',    # For FO-140 and PG-240
                            Uprn      => '',
                        },
                        # Successful collection last working day
                        {   LogDate   => '2024-04-19T10:00:00.977',
                            Reason    => 'N/A',
                            RoundCode => 'RES-R3',    # For RES-240
                            Uprn      => '',
                        },
                        # Successful collection last working day,
                        # marked against individual property
                        {   LogDate   => '2024-04-19T10:00:00.977',
                            Reason    => 'N/A',
                            RoundCode => 'RES-R4',    # For RES-660
                            Uprn      => '10001',
                        },
                        # Successful collection earlier than allowed window
                        {   LogDate   => '2024-04-16T10:00:00.977',
                            Reason    => 'N/A',
                            RoundCode => 'GDN-R1',    # For GA-240
                            Uprn      => '',
                        },
                    ],
                };
            },
        );
        $cobrand->{c}->mock( cobrand => sub {$cobrand} );

        is $cobrand->can_report_missed( $property, $services{'RES-SACK'} ), 0,
            'cannot report missed collection against service with an open report';

        is $cobrand->can_report_missed( $property, $services{'MDR-SACK'} ), 0,
            'cannot report missed collection against service with round exceptions';

        is $cobrand->can_report_missed( $property, $services{'FO-23'} ), 0,
            'cannot report missed collection against service due today that has not been collected';
        ok !$services{'FO-23'}{last}{is_delayed}, 'not marked delayed';

        is $cobrand->can_report_missed( $property, $services{'FO-140'} ), 1,
            'can report missed collection against service due today that *has* been collected';
        ok !$services{'FO-140'}{last}{is_delayed}, 'not marked delayed';

        is $cobrand->can_report_missed( $property, $services{'RES-180'} ), 0,
            'cannot report missed collection against service due yesterday whose round is not logged as collected';
        ok $services{'RES-180'}{last}{is_delayed}, 'marked delayed';

        FixMyStreet::override_config {
            COBRAND_FEATURES => { whitespace => { bexley => {
                use_expected_collection_datetime => 1,
                } },
            },
        }, sub {
            is $cobrand->can_report_missed( $property, $services{'RES-180'} ), 1,
                'can report missed collection against service due yesterday whose round is not logged as collected when '
                . '"use_expected_collections_datetime" is set, so it is considered to have been collected';
        };

        is $cobrand->can_report_missed( $property, $services{'RES-240'} ), 1,
            'can report missed collection against service due yesterday whose round *is* logged as collected';
        ok !$services{'RES-240'}{last}{is_delayed}, 'not marked delayed';

        is $cobrand->can_report_missed( $property, $services{'RES-660'} ), 1,
            'can report missed collection against service due yesterday whose round *is* logged as collected (against individual property)';
        ok !$services{'RES-660'}{last}{is_delayed}, 'not marked delayed';

        is $cobrand->can_report_missed( $property, $services{'GA-240'} ), 0,
            'cannot report missed collection against service whose round was collected more than 3 working days ago';
        ok !$services{'GA-240'}{last}{is_delayed}, 'not marked delayed';

        is $cobrand->can_report_missed( $property, $services{'PG-240'} ), 0,
            'cannot report missed collection against service whose round was collected more than 3 working days ago';
        ok !$services{'PG-240'}{last}{is_delayed}, 'not marked delayed';

        # After 5pm, so FO-23 is now considered delayed
        set_fixed_time('2024-04-22T17:00:00');
        is $cobrand->can_report_missed( $property, $services{'FO-23'} ), 0,
            'cannot report missed collection after 5pm against service due today that has not been collected';
        ok $services{'FO-23'}{last}{is_delayed}, 'marked delayed';

        # Put time back to previous value
        set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST
    };
    my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UK');
    $ukc->mock('_get_bank_holiday_json', sub {
        {
            "england-and-wales" => {
                "events" => [
                    { "date" => "2024-04-01", "title" => 'Easter Monday' }
                ]
            }
        }
    });

    subtest 'bank holiday message' => sub {
        # 15 days before the bank holiday
        set_fixed_time('2024-03-17T02:00:00');
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Collections will be a day later than usual in the week following the bank holiday.', 'Bank holiday message not shown more than a week before');

        # 14 days before the bank holiday
        set_fixed_time('2024-03-18T02:00:00');
        $mech->get_ok('/waste/10001');
        $mech->content_contains('Collections will be a day later than usual in the week following the bank holiday.', 'Bank holiday message shown a week before');

        # Should still show the message on the day of the bank holiday
        set_fixed_time('2024-04-01T02:00:00');
        $mech->get_ok('/waste/10001');
        $mech->content_contains('Collections will be a day later than usual in the week following the bank holiday.', 'Bank holiday message shown on the day');

        # Should show the message for 1 week after the bank holiday
        set_fixed_time('2024-04-08T02:00:00');
        $mech->get_ok('/waste/10001');
        $mech->content_contains('Collections will be a day later than usual in the week following the bank holiday.', 'Bank holiday message shown one week after bank holiday');

        # Shouldn't show the message after 1 week
        set_fixed_time('2024-04-09T02:00:00');
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Collections will be a day later than usual in the week following the bank holiday.', 'Bank holiday message not shown more than one week after');

        # Should show the message if custom query parameter provided, even if more than a week before
        set_fixed_time('2024-03-01T02:00:00');
        $mech->get_ok('/waste/10001?show_bank_holiday_message=1');
        $mech->content_contains('Collections will be a day later than usual in the week following the bank holiday.', 'Bank holiday message shown with custom query parameter');

        # Put time back to previous value
        set_fixed_time('2024-03-31T02:00:00'); # March 31st, 02:00 BST
    };

    subtest 'Deduplication of in-cab logs' => sub {
        $whitespace_mock->mock('GetInCabLogsByUsrn', sub {
            return [
                # Two logs with same reason, round code and date but different times
                {
                    LogID => 1,
                    Reason => 'Refuse - Not Out',
                    RoundCode => 'RES-R3',
                    LogDate => '2024-04-01T10:02:15.7',
                    Uprn => '10001',
                    Usrn => '321',
                },
                {
                    LogID => 2,
                    Reason => 'Refuse - Not Out',
                    RoundCode => 'RES-R3',
                    LogDate => '2024-04-01T10:05:20.1',
                    Uprn => '10001',
                    Usrn => '321',
                },
                # Different date, should be included
                {
                    LogID => 3,
                    Reason => 'Refuse - Not Out',
                    RoundCode => 'RES-R3',
                    LogDate => '2024-04-02T10:02:15.7',
                    Uprn => '10001',
                    Usrn => '321',
                },
                # Different reason, should be included
                {
                    LogID => 4,
                    Reason => 'Food - Not Out',
                    RoundCode => 'RES-R3',
                    LogDate => '2024-04-01T10:02:15.7',
                    Uprn => '10001',
                    Usrn => '321',
                },
                # Different round code, should be included
                {
                    LogID => 5,
                    Reason => 'Refuse - Not Out',
                    RoundCode => 'RES-R4',
                    LogDate => '2024-04-01T10:02:15.7',
                    Uprn => '10001',
                    Usrn => '321',
                },
            ];
        });

        set_fixed_time('2024-04-03T12:00:00');
        $mech->get_ok('/waste/10001');
        $mech->content_contains('Service status');
        $mech->content_contains('Our collection teams have reported the following problems with your bins:');

        # Count occurrences of each type of message
        my $content = $mech->content;
        my $refuse_not_out_count = () = $content =~ /Refuse - Not Out/g;
        my $food_not_out_count = () = $content =~ /Food - Not Out/g;

        is($refuse_not_out_count, 3, "Shows three 'Refuse - Not Out' messages (two different dates, one different round)");
        is($food_not_out_count, 1, "Shows one 'Food - Not Out' message");

        # Reset mock and time
        default_mocks();
        set_fixed_time('2024-03-31T01:00:00');
    };

    subtest 'Missed enquiry form for properties with no collections' => sub {
        $mech->delete_problems_for_body( $body->id );

        $mech->get_ok('/waste/10006');
        $mech->content_contains('/waste/10006/enquiry?template=no-collections', 'link to no collections form present');
        $mech->get_ok('/waste/10006/enquiry?template=no-collections');
        $mech->submit_form_ok( { with_fields => { category => 'Missed collection enquiry' } } );
        $mech->content_contains('Which collections would you like to report as missed?');
        $mech->content_contains('Paper/card recycling');
        $mech->submit_form_ok( { with_fields => { extra_waste_types => 'Refuse' } } );
        $mech->content_contains('Full name');
        $mech->submit_form_ok( { with_fields => { name => 'Test User', email => 'test@example.org' } } );
        $mech->content_contains('Refuse');
        $mech->content_contains('Test User');
        $mech->content_contains('test@example.org');
        $mech->content_contains('Please review the information you’ve provided before you submit your enquiry.');
        $mech->submit_form_ok( { with_fields => { submit => 'Submit' } } );
        $mech->content_contains('Your enquiry has been submitted');

        $mech->clear_emails_ok; # Clear initial confirmation email
        FixMyStreet::Script::Reports::send();

        $mech->email_count_is(2);
        for ($mech->get_email) {
            if ( $_->header('To') =~ /waste-enquiry\@example.org/ ) {
                is $_->header('From'),
                    '"London Borough of Bexley" <do-not-reply@example.org>',
                    'email sent to client is marked as being from council';
            }
        }
    };

    foreach (
        { id => 10006, complaint_type => 'WRBDEL', containers => ['Paper/card recycling', 'Plastic, can and glass recycling'] },
        { id => 10002, complaint_type => 'WFEE', containers => ['Food waste'] },
    ) {
        subtest "Request enquiry form for property $_->{id}" => sub {
            my $joined = join('; ', @{$_->{containers}});
            $mech->delete_problems_for_body( $body->id );
            $mech->get_ok("/waste/$_->{id}");
            $mech->follow_link_ok({ url_regex => qr{/waste/$_->{id}/enquiry\?category=Replacement\+bin\+enquiry} });
            $mech->content_contains('Which container(s) do you require?');
            foreach (@{$_->{containers}}) {
                $mech->content_contains($_);
                $mech->tick('extra_Container', $_);
            }
            $mech->submit_form_ok( { form_number => 1 } );
            $mech->content_contains('Full name');
            $mech->submit_form_ok( { with_fields => { name => 'Test User', email => 'test@example.org' } } );
            $mech->content_contains($joined);
            $mech->content_contains('Test User');
            $mech->content_contains('test@example.org');
            $mech->content_contains('Please review the information you’ve provided before you submit your enquiry.');
            $mech->submit_form_ok( { with_fields => { submit => 'Submit' } } );
            $mech->content_contains('Your enquiry has been submitted');

            my $report = FixMyStreet::DB->resultset('Problem')->first;
            is_deeply $report->get_extra_field_value('Container'), $_->{containers};
            is $report->get_extra_field_value('complaint_type'), $_->{complaint_type};

            $mech->clear_emails_ok; # Clear initial confirmation email
            FixMyStreet::Script::Reports::send();

            $mech->email_count_is(2);
            my ($email_submit, $email_logged) = $mech->get_email;
            $email_submit = $mech->get_html_body_from_email($email_submit);
            $email_logged = $mech->get_text_body_from_email($email_logged);
            like $email_logged, qr{Bins requested: $joined};
            like $email_submit, qr{<td><p>New/replacement container</p></td> <td><p>$joined};
            like $email_submit, qr{<td><p>UPRN</p></td> <td><p>$_->{id}</p></td>}
        };
    }

    subtest 'Request assisted collection form' => sub {
        my @fields = ('reason_for_collection', 'bin_location', 'permanent_or_temporary_help', 'assisted_staff_notes');
        $mech->get_ok('/waste/10006');
        $mech->content_contains('enquiry?category=Request+assisted+collection', "Page contains link to assisted collection form");
        $mech->content_contains('Get help with putting your bins out', "Page contains label for link to assisted collection form");
        $mech->get_ok('/waste/10006/enquiry?category=Request+assisted+collection');
        my $staff_field = pop(@fields);
        for my $field (@fields) {
            $mech->content_contains($field, "$field is present");
        }
        $mech->content_lacks($staff_field, "$staff_field is not present");
        $mech->submit_form_ok( {
            with_fields => {
                extra_reason_for_collection => 'Physical impairment/Elderly resident',
                extra_bin_location => "Behind the blue gate",
                extra_permanent_or_temporary_help => "Permanent",
            }
        }, 'Submit request details page');
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Gary Green',
                email => 'gg@example.com',
            }
        }, 'Submit about you page');
        subtest 'Summary page contains questions but not Staff Notes field' => sub {
            $mech->content_contains('Permanent Or Temporary Help');
            $mech->content_contains('Reason For Collection');
            $mech->content_contains('Bin Location');
            $mech->content_lacks('Assisted Staff Notes');
        };

        $mech->submit_form_ok({form_number => 3});
        $mech->content_lacks('Respond to this request', "Link to approve not present for public");
    };

    subtest 'Request assisted collection report' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        my $id = $report->id;
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('A copy has been sent to your email address, gg@example.com.');
        $mech->content_contains("Your reference number is <strong>$id</strong>.");
        is $report->title, 'Request assisted collection';
        is $report->detail, "Behind the blue gate\n\nPermanent\n\nPhysical impairment/Elderly resident\n\nFlat, 98a-99b The Court, 1a-2b The Avenue, Little Bexlington, Bexley, DA1 3NP";
    };

    subtest 'Request assisted collection emails' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();

        my @emails = $mech->get_email;
        my ($customer_email) = grep { $_->header('to') eq 'gg@example.com' } @emails;
        is $customer_email->header('subject'), 'Thank you for your request for an assisted collection', "Correct customer email subject";
        my ($bexley_email) = grep { $_->header('to') eq '"London Borough of Bexley" <assisted@example.org>' } @emails;
        is $bexley_email->header('subject'), 'New Request assisted collection - Reference number: ' . $report->id, , "Correct council email subject";
        my $customer_text = $mech->get_text_body_from_email($customer_email);
        my $customer_html = $mech->get_html_body_from_email($customer_email);
        my $council_text  = $mech->get_text_body_from_email($bexley_email);
        my $council_html  = $mech->get_html_body_from_email($bexley_email);

        subtest 'Both council and public emails contain request data' => sub {
            for my $email ($customer_text, $customer_html, $council_text, $council_html) {
                like $email, qr#Why do you need an extra collection\?: Physical impairment/Elderly resident#, "Question and answer present";
                like $email, qr/Where are the bins located\?: Behind the blue gate/, "Question and answer present";
                like $email, qr/Is this request for permanent or temporary help\?: Permanent/, "Question and answer present";
                like $email, qr/Flat, 98a-99b The Court, 1a-2b The Avenue, Little Bexlington, Bexley, DA1 3NP/, "Address present";
            };
        };
        subtest 'Customer emails have correct data' => sub {
            for my $email ($customer_text, $customer_html) {
                like $email, qr/Thank you for your request for an assisted collection/;
                like $email, qr/We will look into your request and get back to you as soon as possible/;
                like $email, qr/If you need to contact us about this enquiry, please quote your reference number/;
                unlike $email, qr/Staff notes/, "Staff notes field not included";
            }
        };
        subtest 'Council emails contain reporters information and approval form link' => sub {
            my $report_id = $report->id;
            for my $email ($council_text, $council_html) {
                    like $email, qr/Gary Green/, 'Name included';
                    like $email, qr/gg\@example.com/, 'Email address included';
                    like $email, qr#Staff notes: N/A - public request#, 'Staff notes populated for a public made request';
                    like $email, qr/assisted\/$report_id/, 'Staff emails include link to approval form';
                }
        };
        like $council_html, qr/for back office only/, "Back office notice included in council email";
    };

    subtest 'Request assisted collection staff field' => sub {
        &_delete_all_assisted_collection_reports;
        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/10006/enquiry?category=Request+assisted+collection');
        $mech->submit_form_ok( {
            with_fields => {
                extra_reason_for_collection => 'Physical impairment/Elderly resident',
                extra_bin_location => "Behind the blue gate",
                extra_permanent_or_temporary_help => "Permanent",
                extra_assisted_staff_notes => "Stairs down to pavement"
            }
        });
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Glenda Green',
                email => 'gg@example.com',
            }
        });
        $mech->content_contains('Assisted Staff Notes', "Summary data has Staff Notes key");
        $mech->content_contains('Stairs down to pavement', "Summary data has Staff Notes contents");

        $mech->submit_form_ok({ form_number => 3 });

        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        my $report_id = $report->id;
        $mech->content_contains("<a href=\"http://bexley.example.org/waste/10006/assisted/$report_id\">Respond to this request</a>", "Link for staff to approve/deny request present");
        unlike $report->detail, qr/Stairs down to pavement/, "Staff Notes data not added to report";

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my ($customer_email) = grep { $_->header('to') eq 'gg@example.com' } @emails;
        my ($bexley_email) = grep { $_->header('to') eq '"London Borough of Bexley" <assisted@example.org>' } @emails;
        for my $email ($mech->get_html_body_from_email($customer_email), $mech->get_text_body_from_email($customer_email)) {
            unlike $email, qr/Staff Notes/, "Customer email has no Staff Notes field";
            unlike $email, qr/Stairs down to pavement/, "Customer email has no Staff Notes data";
        };
        for my $email ($mech->get_html_body_from_email($bexley_email), $mech->get_text_body_from_email($bexley_email)) {
            like $email, qr/Staff notes/, "Council email has Staff Notes field";
            like $email, qr/Stairs down to pavement/, "Council email has Staff Notes data";;
        };
    };

    subtest 'Request assisted collection approval' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        $mech->get_ok('/waste/10006/assisted/' . $report->id);
        $mech->submit_form_ok( { with_fields => {outcome_choice => 'Approve'} } );
        $mech->submit_form_ok( {
            with_fields => {
                assisted_duration => '3 Months',
                assisted_reason => 'property',
                assisted_location => 'Behind the back gate',
            }
        });

        like $mech->content, qr/Assisted collection summary/, "On summary page";
        like $mech->content, qr#Assisted collection approve/deny#, "Approve/deny section shown";
        like $mech->content, qr#Approve/deny</dt>#, "Approve/deny choice shown";
        like $mech->content, qr#Approve</dd>#, "Option shown: approve";
        like $mech->content, qr/Approval submission/, 'Approval submission section shown';
        like $mech->content, qr#Reason for assistance</dt>#, "Reason choice shown";
        like $mech->content, qr#property</dd>#, "Option shown: property";
        like $mech->content, qr#Duration of assistance</dt>#, "Duration choice shown";
        like $mech->content, qr#3 Months</dd>#, "Option shown: 3 Months";
        like $mech->content, qr#Location of bins</dt>#, "Location shown";
        like $mech->content, qr#Behind the back gate</dd>#, "Location notes shown";

        $mech->submit_form_ok( { form_number => 1 } );
        $mech->content_contains('Assisted collection outcome', "Returned to outcome choice page");
        $mech->submit_form_ok();
        $mech->submit_form_ok();

        $mech->submit_form_ok( { form_number => 2 } );
        $mech->content_contains('Assisted collection details', "Returned to details page");
        $mech->submit_form_ok();

        is $mech->submit_form_ok( { form_number => 3 } ), 1, "Submission form is third form as two change options";

        $mech->clear_emails_ok;
        FixMyStreet::Script::Alerts::send_updates();
        my $email = $mech->get_email;
        is $email->header('to'), 'gg@example.com', "Update sent to customer";
        my $email_html = $mech->get_html_body_from_email($email);
        like $email_html, qr/Your request for an assisted collection has been approved/, 'Approval update text sent to customer';

        $report->discard_changes;
        is $report->state, 'fixed - council', "Request report marked fixed";

        my $open311_report = FixMyStreet::DB->resultset('Problem')->search( { category => 'Assisted collection add' } )->first;
        is $open311_report->get_extra_field_value('assisted_reason'), 'property';
        is $open311_report->get_extra_field_value('assisted_duration'), '3 Months';
        is $open311_report->get_extra_field_value('assisted_location'), 'Behind the back gate';
    };

    subtest 'Request assisted collection denial' => sub {
        &_delete_all_assisted_collection_reports;
        $mech->log_out_ok;
        $mech->get_ok('/waste/10006/enquiry?category=Request+assisted+collection');
        $mech->submit_form_ok( {
            with_fields => {
                extra_reason_for_collection => 'Physical impairment/Elderly resident',
                extra_bin_location => "Behind the blue gate",
                extra_permanent_or_temporary_help => "Permanent",
            }
        });
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Glenda Green',
                email => 'gg@example.com',
            }
        });
        $mech->submit_form_ok({ form_number => 3 });
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;

        $mech->log_in_ok($staff->email);
        $mech->get_ok('/waste/10006/assisted/' . $report->id);
        $mech->submit_form_ok( { with_fields => { outcome_choice => 'Deny' }} );
        like $mech->content, qr#Assisted collection approve/deny#, "On summary page";
        like $mech->content, qr#Approve/deny</dt>#, "Can change approve/deny choice";
        is $mech->submit_form_ok( { form_number => 2 } ), 1, "Submission form is second form as only one change option";

        $mech->clear_emails_ok;
        FixMyStreet::Script::Alerts::send_updates();
        my $email = $mech->get_email;
        is $email->header('to'), 'gg@example.com', "Update sent to customer";
        my $email_html = $mech->get_html_body_from_email($email);
        like $email_html, qr/Your request for an assisted collection has been denied/, 'Denial update text sent to customer';

        $report->discard_changes;
        is $report->state, 'closed', 'Request report has been closed';

        my $open311_report = FixMyStreet::DB->resultset('Problem')->search( { category => 'Assisted collection add' } )->first;
        is $open311_report, undef, "No approval report created";
    };
};

# Create a response template for missed collection contact
my $cancelled_template = $body->response_templates->create(
    {   auto_response        => 1,
        external_status_code => 'Cancelled',
        state                => '',
        text                 => 'This collection has been cancelled.',
        title                => 'Cancelled template',
    },
);
$cancelled_template->contact_response_templates->find_or_create(
    { contact_id => $contact->id },
);

FixMyStreet::override_config {
    COBRAND_FEATURES => {
        whitespace => {
            bexley => {
                url => 'http://example.org/',
                missed_collection_state_mapping => {
                    'Overdue' => {
                        fms_state => 'action scheduled',
                        text       => 'Collection overdue.',
                    },
                    'Duplicate worksheet' => {
                        fms_state => 'duplicate',
                        text => 'This report has been closed because it was a duplicate.',
                    },
                    'Not Out' => {
                        fms_state => 'unable to fix',
                        text       =>
                            'Our waste collection contractor has advised that this bin collection could not be completed because your bin, box or sack was not out for collection.',
                    },
                    'Cancelled' => {
                        fms_state => 'closed',
                        text       => 'Collection cancelled.',
                    },
                },
            },
        },
    },
}, sub {
    subtest 'Updates for missed collection reports' => sub {
        $whitespace_mock->mock( 'GetFullWorksheetDetails', sub {
            my ( $self, $ws_id ) = @_;
            return {
                2002 => {
                    WSServiceProperties => {
                        WorksheetServiceProperty => [
                            {
                                ServicePropertyID => 1,
                            },
                        ],
                    },
                },
                2003 => {
                    WSServiceProperties => {
                        WorksheetServiceProperty => [
                            {
                                ServicePropertyID => 1,
                            },
                            {
                                ServicePropertyID => 68,
                                ServicePropertyValue => 'Overdue', # 'action scheduled'
                            },
                        ],
                    },
                },
                2004 => {
                    WSServiceProperties => {
                        WorksheetServiceProperty => [
                            {
                                ServicePropertyID => 68,
                                ServicePropertyValue => 'Duplicate worksheet', # 'duplicate'
                            },
                        ],
                    },
                },
                2005 => {
                    WSServiceProperties => {
                        WorksheetServiceProperty => [
                            {
                                ServicePropertyID => 68,
                                ServicePropertyValue => 'Not Out', # 'unable to fix'
                            },
                        ],
                    },
                },
                2006 => {
                    WSServiceProperties => {
                        WorksheetServiceProperty => [
                            {
                                ServicePropertyID => 68,
                                ServicePropertyValue => 'Cancelled', # 'closed'
                            },
                        ],
                    },
                },
            }->{$ws_id};
        });

        my $cobrand = FixMyStreet::Cobrand::Bexley->new;

        $mech->delete_problems_for_body( $body->id );

        my @reports;
        for my $id ( 2001..2006 ) {
            my ($r) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Missed collection',
                {
                    category    => 'Report missed collection',
                    external_id => "Whitespace-$id",
                },
            );

            if ( $id == 2003 || $id == 2005 ) {
                $r->state('action scheduled');
                $r->add_to_comments(
                    {
                        external_id   => 'waste',
                        problem_state => $r->state,
                        text => "Preexisting comment for worksheet $id",
                        user          => $comment_user,
                    }
                );
            } else {
                $r->state('confirmed');
            }

            # Force explicit lastupdate, otherwise it will use real
            # time and not set_fixed_time
            $r->lastupdate( DateTime->now );
            $r->update;

            push @reports, $r;
        }

        my $lines = join '\n', (
            'Fetching data for report \d+',
            '  No new state, skipping',
            'Fetching data for report \d+',
            '  No new state, skipping',
            'Fetching data for report \d+',
            '  Latest update matches fetched state, skipping',
            'Fetching data for report \d+',
            '  Updating report to state \'duplicate\'.*',
            'Fetching data for report \d+',
            '  Updating report to state \'unable to fix\'.*',
        );
        stdout_like {
            $cobrand->waste_fetch_events( { verbose => 1 } )
        } qr/$lines/;

        my @got;
        for my $r (@reports) {
            $r->discard_changes;

            my @comments;
            for my $c (
                sort { $a->problem_state cmp $b->problem_state }
                $r->comments->all
            ) {
                push @comments, {
                    problem_state => $c->problem_state,
                    user_id       => $c->user_id,
                    external_id   => $c->external_id,
                    text          => $c->text,
                };
            }

            push @got, {
                external_id => $r->external_id,
                state       => $r->state,
                comments    => \@comments,
            };
        }

        cmp_deeply \@got, [
            # No worksheet so no update
            {   external_id => 'Whitespace-2001',
                state       => 'confirmed',
                comments    => [],
            },
            # No missed collection data for worksheet, so no update
            {   external_id => 'Whitespace-2002',
                state       => 'confirmed',
                comments    => [],
            },
            # No state change, so no update
            {   external_id => 'Whitespace-2003',
                state       => 'action scheduled',
                comments    => [
                    {
                        external_id   => 'waste',
                        problem_state => 'action scheduled',
                        text => 'Preexisting comment for worksheet 2003',
                        user_id       => $comment_user->id,
                    },
                ],
            },
            # Update (no preexisting comment)
            {   external_id => 'Whitespace-2004',
                state       => 'duplicate',
                comments    => [
                    {
                        external_id   => 'waste',
                        problem_state => 'duplicate',
                        text          => 'This report has been closed because it was a duplicate.',
                        user_id       => $comment_user->id,
                    },
                ],
            },
            # Update (with preexisting comment)
            {   external_id => 'Whitespace-2005',
                state       => 'unable to fix',
                comments    => [
                    {
                        external_id   => 'waste',
                        problem_state => 'action scheduled',
                        text => 'Preexisting comment for worksheet 2005',
                        user_id       => $comment_user->id,
                    },
                    {
                        external_id   => 'waste',
                        problem_state => 'unable to fix',
                        text          => 'Our waste collection contractor has advised that this bin collection could not be completed because your bin, box or sack was not out for collection.',
                        user_id       => $comment_user->id,
                    },
                ],
            },
            # Update (with template text)
            {   external_id => 'Whitespace-2006',
                state       => 'closed',
                comments    => [
                    {
                        external_id   => 'waste',
                        problem_state => 'closed',
                        text          => $cancelled_template->text,
                        user_id       => $comment_user->id,
                    },
                ],
            },
        ], 'correct reports updated with comments added';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    COBRAND_FEATURES => {
        whitespace => {
            bexley => {
                url => 'http://example.org/',
                missed_collection_state_mapping => {
                    'Overdue' => {
                        fms_state => 'action scheduled',
                        text       => 'Collection overdue.',
                    },
                    'Duplicate worksheet' => {
                        fms_state => 'duplicate',
                        text => 'This report has been closed because it was a duplicate.',
                    },
                    'Not Out' => {
                        fms_state => 'unable to fix',
                        text       =>
                            'Our waste collection contractor has advised that this bin collection could not be completed because your bin, box or sack was not out for collection.',
                    },
                    'Cancelled' => {
                        fms_state => 'closed',
                        text       => 'Collection cancelled.',
                    },
                },
                push_secret => 'mySecret'
            },
        },
        waste => { bexley => 1 },
    },
}, sub {
    subtest 'Updates for missed collection reports via endpoint' => sub {
        my $cobrand = FixMyStreet::Cobrand::Bexley->new;

        $mech->delete_problems_for_body( $body->id );

        my @reports;
        for my $id ( 2001..2006 ) {
            my ($r) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Missed collection',
                {
                    category    => 'Report missed collection',
                    external_id => "Whitespace-$id",
                },
            );

            if ( $id == 2003 || $id == 2005 ) {
                $r->state('action scheduled');
                $r->add_to_comments(
                    {
                        external_id   => 'waste',
                        problem_state => $r->state,
                        text => "Preexisting comment for worksheet $id",
                        user          => $comment_user,
                    }
                );
            } else {
                $r->state('confirmed');
            }

            # Force explicit lastupdate, otherwise it will use real
            # time and not set_fixed_time
            $r->lastupdate( DateTime->now );
            $r->update;

            push @reports, $r;
        }

        for my $details (
            {
                id => 2003,
                ref => $reports[2]->id,
                status => 'Overdue'
            },
            {
                id => 2004,
                ref => $reports[3]->id,
                status => 'Duplicate worksheet'
            },
            {
                id => 2005,
                ref => $reports[4]->id,
                status => 'Not Out'
            },
            {
                id => 2006,
                ref => $reports[5]->id,
                status => 'Cancelled'
            }
        ) {
            is $mech->post('/waste/whitespace', Content_Type => 'text/xml', Content => '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                xmlns:web="https://www.jadu.net/hubis/webservices">
                <soapenv:Header />
                <soapenv:Body>
                    <web:WorksheetPoke>
                        <secret>mySecret</secret>
                        <worksheetId>' . $details->{id} . '</worksheetId>
                        <worksheetReference>' . $details->{ref} . '</worksheetReference>
                        <status>' . $details->{status} . '</status>
                        <completedDate>2024-10-02T06:46:12</completedDate>
                    </web:WorksheetPoke>
                </soapenv:Body>
            </soapenv:Envelope>')->code, 200;
        };

        my @got;
        for my $r (@reports) {
            $r->discard_changes;

            my @comments;
            for my $c (
                sort { $a->problem_state cmp $b->problem_state }
                $r->comments->all
            ) {
                push @comments, {
                    problem_state => $c->problem_state,
                    user_id       => $c->user_id,
                    external_id   => $c->external_id,
                    text          => $c->text,
                };
            }

            push @got, {
                external_id => $r->external_id,
                state       => $r->state,
                comments    => \@comments,
            };
        }

        cmp_deeply \@got, [
            # No whitespace update, so no update
            {   external_id => 'Whitespace-2001',
                state       => 'confirmed',
                comments    => [],
            },
            # No whitespace update, so no update
            {   external_id => 'Whitespace-2002',
                state       => 'confirmed',
                comments    => [],
            },
            # No state change, so no update
            {   external_id => 'Whitespace-2003',
                state       => 'action scheduled',
                comments    => [
                    {
                        external_id   => 'waste',
                        problem_state => 'action scheduled',
                        text => 'Preexisting comment for worksheet 2003',
                        user_id       => $comment_user->id,
                    },
                ],
            },
            # Update (no preexisting comment)
            {   external_id => 'Whitespace-2004',
                state       => 'duplicate',
                comments    => [
                    {
                        external_id   => 'waste',
                        problem_state => 'duplicate',
                        text          => 'This report has been closed because it was a duplicate.',
                        user_id       => $comment_user->id,
                    },
                ],
            },
            # Update (with preexisting comment)
            {   external_id => 'Whitespace-2005',
                state       => 'unable to fix',
                comments    => [
                    {
                        external_id   => 'waste',
                        problem_state => 'action scheduled',
                        text => 'Preexisting comment for worksheet 2005',
                        user_id       => $comment_user->id,
                    },
                    {
                        external_id   => 'waste',
                        problem_state => 'unable to fix',
                        text          => 'Our waste collection contractor has advised that this bin collection could not be completed because your bin, box or sack was not out for collection.',
                        user_id       => $comment_user->id,
                    },
                ],
            },
            # Update (with template text)
            {   external_id => 'Whitespace-2006',
                state       => 'closed',
                comments    => [
                    {
                        external_id   => 'waste',
                        problem_state => 'closed',
                        text          => $cancelled_template->text,
                        user_id       => $comment_user->id,
                    },
                ],
            },
        ], 'correct reports updated with comments added';
    };

};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    COBRAND_FEATURES => {
        whitespace => {
            bexley => {
                url => 'http://example.org/',
                missed_collection_state_mapping => {
                    'Overdue' => {
                        fms_state => 'action scheduled',
                        text       => 'Collection overdue.',
                    },
                },
                push_secret => 'mySecret'
            },
        },
        waste => { bexley => 1 },
    },
}, sub {
    for my $details (
        {
            id => 2003,
            ref => 6537144,
            status => 'Overdue',
            secret => 'SecretSecret',
            return_code => '401',
            description => 'Unauthorized with wrong secret'
        },
        {
            id => '',
            ref => 6537144,
            status => 'Overdue',
            secret => 'mySecret',
            return_code => '400',
            description => 'Bad request with missing data'
        },
    ) {
        subtest "Check data errors" => sub {
                is $mech->post('/waste/whitespace', Content_Type => 'text/xml', Content => '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                    xmlns:web="https://www.jadu.net/hubis/webservices">
                    <soapenv:Header />
                    <soapenv:Body>
                        <web:WorksheetPoke>
                            <secret>' . $details->{secret} . '</secret>
                            <worksheetId>' . $details->{id} . '</worksheetId>
                            <worksheetReference>' . $details->{ref} . '</worksheetReference>
                            <status>' . $details->{status} . '</status>
                            <completedDate>2024-10-02T06:46:12</completedDate>
                        </web:WorksheetPoke>
                    </soapenv:Body>
                </soapenv:Envelope>')->code, $details->{return_code}, $details->{description};
        };
    };
    subtest "Check post error" => sub {
        is $mech->get('/waste/whitespace')->code, '405', 'Invalid if not post';
    };
    subtest "Check empty body error" => sub {
        is $mech->post('/waste/whitespace', Content_Type => 'text/xml')->code, '400', 'Bad request if no body';
    }
};

sub _delete_all_assisted_collection_reports {
    my @reports = FixMyStreet::DB->resultset('Problem')->search({ -or => [
        category => 'Assisted collection add',
        category => 'Request assisted collection'
    ]})->all;
    for my $report (@reports) {
        my @comments = $report->comments->search()->all;
        for my $comment (@comments) {
            $comment->delete;
            $comment->update;
        }
        $report->delete;
        $report->update;
    };
}

done_testing;
