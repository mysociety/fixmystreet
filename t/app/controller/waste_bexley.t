use Test::Deep;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST

my $mech = FixMyStreet::TestMech->new;

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Bexley');
$mock->mock('_fetch_features', sub { [] });

my $mock_waste = Test::MockModule->new('BexleyAddresses');
# We don't actually read from the file, so just put anything that is a valid path
$mock_waste->mock( 'database_file', '/' );

my $agile_mock = Test::MockModule->new('Integrations::Agile');
$agile_mock->mock( 'CustomerSearch', sub { {} } );

my $dbi_mock = Test::MockModule->new('DBI');
$dbi_mock->mock( 'connect', sub {
    my $dbh = Test::MockObject->new;
    $dbh->mock( 'selectall_arrayref', sub {
        my ( undef, undef, undef, $postcode ) = @_;

        if ( $postcode eq 'DA13LD' ) {
            return [
                {   uprn              => 10001,
                    pao_start_number  => 1,
                    street_descriptor => 'THE AVENUE',
                },
                {   uprn              => 10002,
                    pao_start_number  => 2,
                    street_descriptor => 'THE AVENUE',
                },
            ];
        } elsif ( $postcode eq 'DA13NP' ) {
            return [
                {   uprn              => 10001,
                    sao_start_number  => 98,
                    sao_start_suffix  => 'A',
                    sao_end_number    => 99,
                    sao_end_suffix    => 'B',
                    sao_text          => 'Flat',
                    pao_start_number  => 1,
                    pao_start_suffix  => 'a',
                    pao_end_number    => 2,
                    pao_end_suffix    => 'b',
                    pao_text          => 'The Court',
                    street_descriptor => 'THE AVENUE',
                    locality_name     => 'Little Bexlington',
                    town_name         => 'Bexley',

                    has_parent => 1,
                },
            ];
        }
    } );
    $dbh->mock( 'selectrow_hashref', sub {
        my ( undef, $sql ) = @_;

        if ( $sql =~ /SELECT usrn/ ) { # usrn_for_uprn
            return {
                usrn => 321,
            };
        } else { # address_for_uprn
            return {
                postcode          => 'DA13NP',
                sao_start_number  => 98,
                sao_start_suffix  => 'A',
                sao_end_number    => 99,
                sao_end_suffix    => 'B',
                sao_text          => 'Flat',
                pao_start_number  => 1,
                pao_start_suffix  => 'a',
                pao_end_number    => 2,
                pao_end_suffix    => 'b',
                pao_text          => 'The Court',
                street_descriptor => 'THE AVENUE',
                locality_name     => 'Little Bexlington',
                town_name         => 'Bexley',

                has_parent => 1,
            };
        }
    } );
    return $dbh;
} );

my $whitespace_mock = Test::MockModule->new('Integrations::Whitespace');
sub default_mocks {
    # These are overridden for some tests
    $whitespace_mock->mock(
        'GetSiteCollections',
        sub {
            my ( $self, $uprn ) = @_;
            return _site_collections()->{$uprn};
        }
    );
    $whitespace_mock->mock(
        'GetCollectionByUprnAndDate',
        sub {
            my ( $self, $property_id, $from_date ) = @_;

            return _collection_by_uprn_date()->{$from_date} // [];
        }
    );
    $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub {
        my ( $self, $usrn ) = @_;
        return _in_cab_logs();
    });
};

default_mocks();

$whitespace_mock->mock(
    'GetSiteInfo',
    sub {
        my ( $self, $uprn ) = @_;
        return _site_info()->{$uprn};
    }
);
$whitespace_mock->mock( 'GetAccountSiteID', &_account_site_id );
$whitespace_mock->mock( 'GetSiteWorksheets', &_site_worksheets );
$whitespace_mock->mock(
    'GetWorksheetDetailServiceItems',
    sub {
        my ( $self, $worksheet_id ) = @_;
        return _worksheet_detail_service_items()->{$worksheet_id};
    }
);
my $comment_user = $mech->create_user_ok('comment');
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
            'Your collection schedule is Week 1',
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
            $cobrand->{c}->mock( waste_cache_set => sub {
                Catalyst::Plugin::FixMyStreet::Session::WasteCache::waste_cache_set(@_);
            });

            my $log = Test::MockObject->new;
            $log->mock( info => sub {} );
            $cobrand->{c}->mock( log => sub { $log } );

            $cobrand->{c}->mock( stash => sub { {
                whitespace_data => {
                    'GetSiteCollections 10001' => _site_collections()->{10001},
                    'GetSiteInfo 10001' => _site_info()->{10001},
                },
            } } );

            $cobrand->{c}->mock( cobrand => sub { $cobrand });

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
                    round_schedule => 'RND-1 Tue Wk 1',
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
            $whitespace_mock->mock(
                'GetSiteCollections',
                sub {
                    my ( $self, $uprn ) = @_;
                    return _site_collections()->{$uprn};
                }
            );
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
            'GetCollectionByUprnAndDate',
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

done_testing;

sub _site_info {
    return {
        10001 => {
            AccountSiteID   => 1,
            AccountSiteUPRN => 10001,
            Site            => {
                SiteShortAddress => ', 1, THE AVENUE, DA1 3NP',
                SiteLatitude     => 51.466707,
                SiteLongitude    => 0.181108,
            },
        },
        10002 => {
            AccountSiteID   => 2,
            AccountSiteUPRN => 10002,
            Site            => {
                SiteShortAddress => ', 2, THE AVENUE, DA1 3LD',
                SiteLatitude     => 51.466707,
                SiteLongitude    => 0.181108,
                SiteParentID     => 101,
            },
        },
        10003 => {
            AccountSiteID   => 3,
            AccountSiteUPRN => 10003,
            Site            => {
                SiteShortAddress => ', 3, THE AVENUE, DA1 3LD',
                SiteLatitude     => 51.466707,
                SiteLongitude    => 0.181108,
                SiteParentID     => 101,
            },
        },
        10004 => {
            AccountSiteID   => 4,
            AccountSiteUPRN => 10004,
            Site            => {
                SiteShortAddress => ', 4, THE AVENUE, DA1 3LD',
                SiteLatitude     => 51.466707,
                SiteLongitude    => 0.181108,
                SiteParentID     => 101,
            },
        },
        10005 => {
            AccountSiteID   => 5,
            AccountSiteUPRN => 10005,
            Site            => {
                SiteShortAddress => ', 5, THE AVENUE, DA1 3LD',
                SiteLatitude     => 51.466707,
                SiteLongitude    => 0.181108,
            },
        },
        10006 => {
            AccountSiteID   => 6,
            AccountSiteUPRN => 10006,
            Site            => {
                SiteShortAddress => ', 6, THE AVENUE, DA1 3LD',
                SiteLatitude     => 51.466707,
                SiteLongitude    => 0.181108,
            },
        },
    };
}

sub _account_site_id {
    return {
        AccountSiteUprn => 10001,
    };
}

sub _site_collections {
    return {
        10002 => undef,

        10001 => [
            {   SiteServiceID          => 1,
                ServiceItemDescription => 'Service 1',
                ServiceItemName => 'FO-140', # Communal Food Bin

                NextCollectionDate   => '2024-04-30T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '2024-03-31T03:00:00',

                RoundSchedule => 'RND-1 Tue Wk 1',
            },
            {   SiteServiceID          => 2,
                ServiceItemDescription => 'Service 2',
                ServiceItemName => 'FO-23', # Brown Caddy

                NextCollectionDate   => undef,
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '2024-03-31T03:00:00',

                RoundSchedule => 'N/A',
            },
            {   SiteServiceID          => 3,
                ServiceItemDescription => 'Service 3',
                ServiceItemName => 'GA-140', # Brown Wheelie Bin

                # No NextCollectionDate
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '2024-03-31T03:00:00',

                RoundSchedule => 'N/A',
            },
            {   SiteServiceID          => 4,
                ServiceItemDescription => 'Service 4',
                ServiceItemName => 'GL-1100', # Green Recycling Bin

                NextCollectionDate   => '2024-04-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T03:00:00',    # Future
                SiteServiceValidTo   => '2024-03-31T04:00:00',

                RoundSchedule => 'N/A',
            },
            {   SiteServiceID          => 5,
                ServiceItemDescription => 'Service 5',
                ServiceItemName => 'GL-55', # Black Recycling Box

                NextCollectionDate   => '2024-04-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:00:00',
                SiteServiceValidTo   => '2024-03-31T00:59:59',    # Past

                RoundSchedule => 'N/A',
            },
            {   SiteServiceID          => 6,
                ServiceItemDescription => 'Service 6',
                ServiceItemName => 'RES-CHAM', # Residual Chamberlain

                NextCollectionDate   => '2024-05-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '0001-01-01T00:00:00',

                RoundSchedule => 'RND-6 Wed Wk 2',
            },
            {   SiteServiceID          => 7,
                ServiceItemDescription => 'Service 7',
                ServiceItemName => 'PC-180', # Blue Lidded Wheelie Bin

                NextCollectionDate   => '2024-05-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '0001-01-01T00:00:00',

                RoundSchedule => 'N/A',
            },
            {   SiteServiceID          => 8,
                ServiceItemDescription => 'Service 8',
                ServiceItemName => 'PC-55', # Blue Recycling Box
                ServiceName => 'Blue Recycling Box',
                NextCollectionDate   => '2024-04-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '0001-01-01T00:00:00',

                RoundSchedule => 'RND-8-9 Mon, RND-8-9 Wed',
            },
            {   SiteServiceID          => 8,
                ServiceItemDescription => 'Service 8',
                ServiceItemName => 'PC-55', # Blue Recycling Box
                ServiceName => 'Assisted Collection',
                NextCollectionDate   => '2024-04-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '0001-01-01T00:00:00',

                RoundSchedule => 'RND-8-9 Mon, RND-8-9 Wed',
            },
            {   SiteServiceID          => 9,
                ServiceItemDescription => 'Another service (9)',
                ServiceItemName => 'PA-55', # Green Recycling Box

                NextCollectionDate   => '2024-04-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '0001-01-01T00:00:00',

                RoundSchedule => 'RND-8-9 Mon, RND-8-9 Wed',
            },
            # CW-SACK (Clinical waste) is not in container list so won't be shown
            {
                SiteServiceID          => 99,
                ServiceItemDescription => 'Clinical Waste Sack',
                ServiceItemName        => 'CW-SACK',

                NextCollectionDate   => '2024-04-01T00:00:00',
            },

            # Has same dates and schedule as RES-CHAM above
            {   SiteServiceID          => 10,
                ServiceItemDescription => 'Service 10',
                ServiceItemName => 'PL-940', # White / Silver Recycling Bin

                NextCollectionDate   => '2024-05-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '0001-01-01T00:00:00',

                RoundSchedule => 'RND-6 Wed Wk 2',
            },
        ],
        10003 => [
            {   SiteServiceID          => 1000,
                ServiceID              => 1,
                ServiceItemDescription => 'Residual 180 ltr bin',
                ServiceItemName => 'RES-180',
                NextCollectionDate   => '2024-04-30T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '2024-03-31T03:00:00',

                RoundSchedule => 'RND-1 Tue Wk 1',
            },
        ],
        10004 => [
            {   SiteServiceID          => 2000,
                ServiceID              => 1,
                ServiceItemDescription => 'Residual 180 ltr bin',
                ServiceItemName => 'RES-180',
                NextCollectionDate   => '2024-04-30T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '2024-03-31T03:00:00',

                RoundSchedule => 'RND-1 Tue Wk 2',
            },
        ],
        10005 => [
            {   SiteServiceID          => 2,
                ServiceItemDescription => 'Service 3',
                ServiceItemName => 'GA-140', # Brown Wheelie Bin

                NextCollectionDate   => '2024-04-30T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '2024-03-31T03:00:00',

                RoundSchedule => 'N/A',
            },
        ],
        10006 => [],
        10007 => [ # Filtered out because we already have a Brown Wheelie Bin service'.
            {   SiteServiceID          => 2,
                ServiceItemDescription => 'Service 4',
                ServiceItemName => 'GA-240', # Brown Wheelie Bin

                NextCollectionDate   => '2024-04-30T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '2024-03-31T03:00:00',

                RoundSchedule => 'N/A',
            },
        ],
    };
}

sub _collection_by_uprn_date {
    return {
        # For bin_future_collections
        '2024-4-01T00:00:00' => [
            {   Date     => '01/04/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Mon',
                Service  => 'Services 8 & 9 Collection',
            },
            {   Date     => '02/04/2024 00:00:00',
                Round    => 'RND-1',
                Schedule => 'Tue Wk 1',
                Service  => 'Service 1 Collection',
            },
            {   Date     => '03/04/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Wed',
                Service  => 'Services 8 & 9 Collection',
            },
            {   Date     => '03/04/2024 00:00:00',
                Round    => 'RND-6',
                Schedule => 'Wed Wk 2',
                Service  => 'Service 6 Collection',
            },

            {   Date     => '08/04/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Mon',
                Service  => 'Services 8 & 9 Collection',
            },
            {   Date     => '10/04/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Wed',
                Service  => 'Services 8 & 9 Collection',
            },

            {   Date     => '15/04/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Mon',
                Service  => 'Services 8 & 9 Collection',
            },
            {   Date     => '16/04/2024 00:00:00',
                Round    => 'RND-1',
                Schedule => 'Tue Wk 1',
                Service  => 'Service 1 Collection',
            },
            {   Date     => '17/04/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Wed',
                Service  => 'Services 8 & 9 Collection',
            },
            {   Date     => '17/04/2024 00:00:00',
                Round    => 'RND-6',
                Schedule => 'Wed Wk 2',
                Service  => 'Service 6 Collection',
            },

            # Dupes of May collections below
            {   Date     => '01/05/2024 00:00:00',
                Round    => 'RND-6',
                Schedule => 'Wed Wk 2',
                Service  => 'Service 6 Collection',
            },

            {   Date     => '06/05/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Mon',
                Service  => 'Services 8 & 9 Collection',
            },
        ],
        '2024-5-01T00:00:00' => [
            {   Date     => '01/05/2024 00:00:00',
                Round    => 'RND-6',
                Schedule => 'Wed Wk 2',
                Service  => 'Service 6 Collection',
            },

            {   Date     => '06/05/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Mon',
                Service  => 'Services 8 & 9 Collection',
            },

            {   Date     => '15/05/2024 00:00:00',
                Round    => 'RND-6',
                Schedule => 'Wed Wk 2',
                Service  => 'Service 6 Collection',
            },
        ],

        # For _recent_collections
        '2024-03-02T00:00:00' => [
            {   Date     => '24/03/2024 00:00:00',
                Round    => 'RND-1',
                Schedule => 'Tue Wk 1',
                Service  => 'Service 1 Collection',
            },
            # 3 working days before Sun 31st March = Wed 27th March
            {   Date     => '27/03/2024 00:00:00',
                Round    => 'RND-6',
                Schedule => 'Wed Wk 2',
                Service  => 'Service 6 Collection',
            },
            {   Date     => '27/03/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Wed',
                Service  => 'Services 8 & 9 Collection',
            },
            {   Date     => '28/03/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Mon',
                Service  => 'Services 8 & 9 Collection',
            },
            {   Date     => '31/03/2024 00:00:00',
                Round    => 'RND-1',
                Schedule => 'Tue Wk 1',
                Service  => 'Service 1 Collection',
            },
        ],
    };
}

sub _site_worksheets {
    return [
        {   WorksheetID         => 1,
            WorksheetStatusName => 'Complete',
            WorksheetSubject    => 'Missed Collection Plastics & Glass',

            WorksheetStartDate      => '',
            WorksheetEscallatedDate => '',
        },
        {   WorksheetID         => 2,
            WorksheetStatusName => 'Open',
            WorksheetSubject    => 'Hotspot Location',

            WorksheetStartDate      => '',
            WorksheetEscallatedDate => '',
        },
        {   WorksheetID         => 3,
            WorksheetStatusName => 'Open',
            WorksheetSubject    => 'Missed Collection Plastics & Glass',

            WorksheetStartDate      => '',
            WorksheetEscallatedDate => '',
        },
        {   WorksheetID         => 4,
            WorksheetStatusName => 'Open',
            WorksheetSubject    => 'Missed Collection Paper',

            WorksheetStartDate      => '0001-01-01T00:00:00',
            WorksheetEscallatedDate => '',
        },
        {   WorksheetID         => 5,
            WorksheetStatusName => 'Open',
            WorksheetSubject    => 'Missed Collection Mixed Dry Recycling',

            WorksheetStartDate      => '2024-03-31T01:00:00',
            WorksheetEscallatedDate => '2024-04-02T01:00:00',
        },
    ];
}

sub _worksheet_detail_service_items {
    return {
        2 => [ { ServiceItemName => 'FO-140' } ],
        3 => [],
        4 => [
            { ServiceItemName => 'PC-55' },
        ],
        5 => [
            { ServiceItemName => 'PA-55' },
        ],
    };
}

sub _in_cab_logs {
    [
        {
            LogID => 1,
            Reason => 'Food - Not Out',
            RoundCode => 'RND-1',
            LogDate => '2024-03-28T06:10:09.417',
            Uprn => '10001',
            Usrn => '321',
        },
        {
            LogID => 1,
            Reason => 'N/A',
            RoundCode => 'RND-6',
            LogDate => '2024-03-28T06:10:09.417',
            Uprn => '',
            Usrn => '321',
        },
    ]
}
