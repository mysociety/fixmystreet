use utf8;
use Test::Deep;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';
use Test::Output;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST

my $mech = FixMyStreet::TestMech->new;

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Bexley');
$mock->mock('_fetch_features', sub { [] });

my $mock_waste = Test::MockModule->new('BexleyAddresses');
# We don't actually read from the file, so just put anything that is a valid path
$mock_waste->mock( 'database_file', '/' );

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

                    parent_uprn => 999999,
                },
            ];
        }
    } );
    $dbh->mock( 'selectrow_hashref', sub {
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

            parent_uprn => 999999,
        };
    } );
    return $dbh;
} );

my $whitespace_mock = Test::MockModule->new('Integrations::Whitespace');
$whitespace_mock->mock(
    'GetSiteInfo',
    sub {
        my ( $self, $uprn ) = @_;
        return _site_info()->{$uprn};
    }
);
$whitespace_mock->mock(
    'GetSiteCollections',
    sub {
        my ( $self, $uprn ) = @_;
        return _site_collections()->{$uprn};
    }
);
$whitespace_mock->mock( 'GetAccountSiteID', &_account_site_id );
$whitespace_mock->mock( 'GetCollectionByUprnAndDate',
    sub {
        my ( $self, $property_id, $from_date ) = @_;

        return _collection_by_uprn_date()->{$from_date} // [];
    }
);
$whitespace_mock->mock( 'GetSiteWorksheets', &_site_worksheets );
$whitespace_mock->mock(
    'GetWorksheetDetailServiceItems',
    sub {
        my ( $self, $worksheet_id ) = @_;
        return _worksheet_detail_service_items()->{$worksheet_id};
    }
);
$whitespace_mock->mock( 'GetInCabLogsByUprn', sub {
    my ( $self, $uprn ) = @_;
    return _in_cab_logs()->{$uprn};
});

my $comment_user = $mech->create_user_ok('comment');
my $body = $mech->create_body_ok(
    2494,
    'London Borough of Bexley',
    {
        comment_user           => $comment_user,
        send_extended_statuses => 1,
    },
    { cobrand      => 'bexley' },
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

my ($existing_missed_collection_report1) = $mech->create_problems_for_body(1, $body->id, 'Report missed collection', {
    external_id => "Whitespace-4",
});
my ($existing_missed_collection_report2) = $mech->create_problems_for_body(1, $body->id, 'Report missed collection', {
    external_id => "Whitespace-5",
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => { whitespace => { bexley => {
        url => 'http://example.org/',
        } },
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
        $mech->content_lacks('Subscribe to garden waste collection service');
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
            '<option value="10001">Flat, 98a-99b, The Court, 1a-2b The Avenue, Little Bexlington, Bexley</option>'
        );
    };

    $whitespace_mock->mock( 'GetSiteContracts', sub {
        my ( $self, $uprn ) = @_;
        return [
            {   ContractID => 1,
                ContractName => 'Contract 1',
                ContractType => 'Type 1',
                ContractStartDate => '2024-03-31T00:00:00',
                ContractEndDate => '2024-03-31T00:00:00',
                ContractStatus => 'Active',
            },
        ];
    });

    subtest 'Correct services are shown for address' => sub {
        $mech->submit_form_ok( { with_fields => { address => 10001 } } );

        test_services($mech);
        $mech->content_contains("You do not have a Garden waste collection");

        $mech->content_contains(
            '<dd class="waste__address__property">Flat, 98a-99b, The Court, 1a-2b The Avenue, Little Bexlington, Bexley, DA1 3NP</dd>',
            'Correct address string displayed',
        );
        $mech->content_contains(
            'Your rotation schedule is Week 1',
            'Correct rotation schedule displayed',
        );

        subtest 'service_sort sorts correctly' => sub {
            my $cobrand = FixMyStreet::Cobrand::Bexley->new;
            $cobrand->{c} = Test::MockObject->new;
            $cobrand->{c}->mock( stash => sub { {} } );
            $cobrand->{c}->mock( cobrand => sub { $cobrand });
            my @sorted = $cobrand->service_sort(
                @{  $cobrand->bin_services_for_address( { uprn => 10001 } )
                }
            );
            my %defaults = (
                next => {
                    changed => 0,
                    ordinal => ignore(),
                    date => ignore(),
                    is_today => ignore(),
                },
                last => {
                    ordinal => ignore(),
                    date => ignore(),
                },
            );
            cmp_deeply \@sorted, [
                {   id             => 8,
                    service_id     => 'PC-55',
                    service_name   => 'Blue Recycling Box',
                    service_description => 'Paper and card',
                    round_schedule => 'RND-8-9 Mon, RND-8-9 Wed',
                    round          => 'RND-8-9',
                    report_allowed => 0,
                    report_open    => 1,
                    report_url     => '/report/' . $existing_missed_collection_report1->id,
                    report_locked_out => 0,
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
                    report_open    => 1,
                    report_url     => '/report/' . $existing_missed_collection_report2->id,
                    report_locked_out => 0,
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
                    report_open    => 0,
                    report_locked_out => 1,
                    assisted_collection => 0,
                    schedule => 'Fortnightly',
                    %defaults,
                },
                {   id             => 6,
                    service_id     => 'RES-CHAM',
                    service_name   => 'Communal Refuse Bin(s)',
                    service_description => 'Non-recyclable waste',
                    round_schedule => 'RND-6 Wed Wk 2',
                    round          => 'RND-6',
                    report_allowed => 1,
                    report_open    => 0,
                    report_locked_out => 0,
                    assisted_collection => 0,
                    schedule => 'Fortnightly',
                    %defaults,
                },
            ];

            my %expected_last_dates = (
                8 => '2024-03-28T00:00:00',
                9 => '2024-03-28T00:00:00',
                1 => '2024-03-24T00:00:00',
                6 => '2024-03-27T00:00:00',
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
        $mech->content_lacks('Blue Lidded Wheelie Bin');
        $mech->content_contains('Blue Recycling Box');
        $mech->content_contains('Monday 1 April 2024');
        $mech->content_contains('Green Recycling Box');
        $mech->content_contains('Monday 1 April 2024');
    }

    subtest 'Checking calendar' => sub {
        $mech->follow_link_ok(
            { text => 'Add to your calendar (.ics file)' } );
        $mech->content_contains('BEGIN:VCALENDAR');
        my @events = split /BEGIN:VEVENT/, $mech->encoded_content;
        shift @events; # Header

        my $expected_num = 20;
        is @events, $expected_num, "$expected_num events in calendar";

        my $i = 0;
        for (@events) {
            $i++ if /DTSTART;VALUE=DATE:20240401/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240401/ && /SUMMARY:Green Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240402/ && /SUMMARY:Communal Food Bin/;
            $i++ if /DTSTART;VALUE=DATE:20240403/ && /SUMMARY:Communal Refuse Bin\(s\)/;
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
            $i++ if /DTSTART;VALUE=DATE:20240417/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240417/ && /SUMMARY:Green Recycling Box/;

            $i++ if /DTSTART;VALUE=DATE:20240501/ && /SUMMARY:Communal Refuse Bin\(s\)/;

            $i++ if /DTSTART;VALUE=DATE:20240506/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240506/ && /SUMMARY:Green Recycling Box/;

            $i++ if /DTSTART;VALUE=DATE:20240515/ && /SUMMARY:Communal Refuse Bin\(s\)/;
        }
        is $i, $expected_num, 'Correct events in the calendar';
    };

    subtest 'Correct PDF download link shown' => sub {
        for my $test ({ address => 10003, link => 1 }, { address => 10004, link => 2 }) {
            $mech->get_ok('/waste');
            $mech->submit_form_ok( { with_fields => { postcode => 'DA1 3LD' } } );
            $mech->submit_form_ok( { with_fields => { address => $test->{address} } } );
            $mech->content_contains(
                "Your rotation schedule is Week $test->{link}",
                'Correct rotation schedule displayed',
            );
            $mech->content_contains('<li><a target="_blank" href="PDF '. $test->{link} . '">View and download collection calendar', 'PDF link ' . $test->{link} . ' shown');
        }
    };

    subtest 'Shows when a collection is due today' => sub {
        set_fixed_time('2024-04-01T07:00:00'); # April 1st, 08:00 BST

        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 3LD' } } );
        $mech->submit_form_ok( { with_fields => { address => 10001 } } );

        # Blue and green recycling boxes are due today
        $mech->content_contains('Being collected today');

        # Put time back to previous value
        set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST
    };

    subtest 'Asks user for location of bins on missed collection form' => sub {
        $mech->get_ok('/waste/10001/report');
        $mech->content_contains('Please select bin location');
        $mech->content_contains('name="extra_detail"');
        $mech->content_contains($_)
            for
            @{ FixMyStreet::Cobrand::Bexley::Waste::_bin_location_options()
                ->{staff_or_assisted} };
    };

    subtest 'Making a missed collection report' => sub {
        $mech->get_ok('/waste/10001/report');
        $mech->submit_form_ok(
            { with_fields => { extra_detail => 'Front boundary of property', 'service-RES-CHAM' => 1 } },
            'Selecting missed collection for clear sacks');
        $mech->submit_form_ok(
            { with_fields => { name => 'John Doe', phone => '44 07 111 111 111', email => 'test@example.com' } },
            'Submitting contact details');
        $mech->submit_form_ok(
            { with_fields => { submit => 'Report collection as missed', category => 'Report missed collection' } },
            'Submitting missed collection report');

        $mech->content_contains('Missed collection has been reported');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;

        ok $report->confirmed;
        is $report->state, 'confirmed';
        is $report->get_extra_field_value('uprn'), '10001', 'UPRN is correct';
        is $report->get_extra_field_value('service_item_name'), 'RES-CHAM', 'Service item name is correct';
        is $report->get_extra_field_value('assisted_yn'), 'No', 'Assisted collection is correct';
        is $report->get_extra_field_value('location_of_containers'), 'Front boundary of property', 'Location of containers is correct';
    };

    subtest 'Missed collection reports are made against the parent property' => sub {
        $mech->get_ok('/waste/10002/report');
        $mech->submit_form_ok(
            { with_fields => { extra_detail => 'Rear of property', 'service-RES-CHAM' => 1 } },
            'Selecting missed collection for communal refuse bin');
        $mech->submit_form_ok(
            { with_fields => { name => 'John Doe', phone => '44 07 111 111 111', email => 'test@example.com' } },
            'Submitting contact details');
        $mech->submit_form_ok(
            { with_fields => { submit => 'Report collection as missed', category => 'Report missed collection' } },
            'Submitting missed collection report');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;

        is $report->get_extra_field_value('uprn'), '10001', 'Report is against the parent property';
    };

    subtest 'Prevents missed collection reports if there is an open report' => sub {
        $mech->get_ok('/waste/10002');
        $mech->content_contains('A green recycling box collection has been reported as missed');
        $mech->content_contains('<a href="/report/' . $existing_missed_collection_report2->id . '" class="waste-service-link">check status</a>');
    };

    subtest 'GGW promo not shown if already subscribed' => sub {
        $mech->get_ok('/waste/10005');

        $mech->content_lacks("You do not have a Garden waste collection");
    };

};

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
                        external_id   => $r->external_id,
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
                        external_id   => 'Whitespace-2003',
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
                        external_id   => 'Whitespace-2004',
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
                        external_id   => 'Whitespace-2005',
                        problem_state => 'action scheduled',
                        text => 'Preexisting comment for worksheet 2005',
                        user_id       => $comment_user->id,
                    },
                    {
                        external_id   => 'Whitespace-2005',
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
                        external_id   => 'Whitespace-2006',
                        problem_state => 'closed',
                        text          => $cancelled_template->text,
                        user_id       => $comment_user->id,
                    },
                ],
            },
        ], 'correct reports updated with comments added';
    };
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

                NextCollectionDate   => undef,
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
        '2024-03-10T00:00:00' => [
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
        },
        {   WorksheetID         => 2,
            WorksheetStatusName => 'Open',
            WorksheetSubject    => 'Hotspot Location',
        },
        {   WorksheetID         => 3,
            WorksheetStatusName => 'Open',
            WorksheetSubject    => 'Missed Collection Plastics & Glass',
        },
        {   WorksheetID         => 4,
            WorksheetStatusName => 'Open',
            WorksheetSubject    => 'Missed Collection Paper',
        },
        {   WorksheetID         => 5,
            WorksheetStatusName => 'Open',
            WorksheetSubject    => 'Missed Collection Mixed Dry Recycling',
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
    {
        10001 => [
            {
                Reason => 'Food - Not Out',
                RoundCode => 'RND-1',
                LogDate => '2024-03-28T06:10:09.417',
                Uprn => '10001',
            },
            {
                Reason => 'N/A',
                RoundCode => 'RND-6',
                LogDate => '2024-03-28T06:10:09.417',
                Uprn => '',
            },
        ],
    }
}
