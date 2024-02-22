use utf8;
use Test::Deep;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';
use FixMyStreet::TestMech;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST

my $mech = FixMyStreet::TestMech->new;

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Bexley');
$mock->mock('_fetch_features', sub { [] });

my $whitespace_mock = Test::MockModule->new('Integrations::Whitespace');
$whitespace_mock->mock('call' => sub {
  my ($whitespace, $method, @args) = @_;

  if ($method eq 'GetAddresses') {
    my %args = @args;
    &_addresses_for_postcode($args{getAddressInput});
  }
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
      $mech->submit_form_ok({ with_fields => {postcode => 'PC1 1PC'} });
      $mech->content_contains('Sorry, we did not recognise that postcode');
    };

    subtest 'Postcode with multiple addresses progresses to selecting an address' => sub {
      $mech->submit_form_ok({ with_fields => {postcode => 'DA1 3LD'} });
      $mech->content_contains('Select an address');
      $mech->content_contains('<option value="1">1, The Avenue, DA1 3LD</option>');
      $mech->content_contains('<option value="2">2, The Avenue, DA1 3LD</option>');
  };

  subtest 'Postcode with one address progresses to selecting an address' => sub {
      $mech->get_ok('/waste');
      $mech->submit_form_ok({ with_fields => {postcode => 'DA1 3NP'} });
      $mech->content_contains('Select an address');
      $mech->content_contains('<option value="1">1, The Avenue, DA1 3NP</option>');
  };

    $whitespace_mock->mock(
        'GetSiteInfo',
        sub {
            my ( $self, $account_site_id ) = @_;
            return _site_info()->{$account_site_id};
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
        &_collection_by_uprn_date );
    $whitespace_mock->mock( 'GetCollectionByUprnAndDatePlus',
        &_collection_by_uprn_date_plus );
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

    subtest 'Correct services are shown for address' => sub {
        $mech->submit_form_ok( { with_fields => { address => 1 } } );

        test_services($mech);

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
                    round_schedule => 'RND-8-9 Mon',
                    round          => 'RND-8-9',
                    report_allowed => 0,
                    report_open    => 1,
                    report_locked_out => 0,
                    %defaults,
                },
                {   id             => 9,
                    service_id     => 'PA-55',
                    service_name   => 'Green Recycling Box',
                    round_schedule => 'RND-8-9 Mon',
                    round          => 'RND-8-9',
                    report_allowed => 0,
                    report_open    => 1,
                    report_locked_out => 0,
                    %defaults,
                },
                {   id             => 1,
                    service_id     => 'FO-140',
                    service_name   => 'Communal Food Bin',
                    round_schedule => 'RND-1 Tue Wk 1',
                    round          => 'RND-1',
                    report_allowed => 0,
                    report_open    => 0,
                    report_locked_out => 1,
                    %defaults,
                },
                {   id             => 6,
                    service_id     => 'MDR-SACK',
                    service_name   => 'Clear Sack(s)',
                    round_schedule => 'RND-6 Wed Wk 2',
                    round          => 'RND-6',
                    report_allowed => 1,
                    report_open    => 0,
                    report_locked_out => 0,
                    %defaults,
                },
            ];
        };
    };

    subtest 'Parent services shown for child' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 3LD' } } );
        $mech->submit_form_ok( { with_fields => { address => 2 } } );

        test_services($mech);
    };

    sub test_services {
        my $mech = shift;

        $mech->content_contains('Communal Food Bin');
        $mech->content_contains('Tuesday, 30th April 2024');
        $mech->content_lacks('Brown Caddy');
        $mech->content_lacks('Brown Wheelie Bin');
        $mech->content_lacks('Green Recycling Bin');
        $mech->content_lacks('Black Recycling Box');
        $mech->content_contains('Clear Sack(s)');
        $mech->content_contains('Wednesday, 1st May 2024');
        $mech->content_lacks('Blue Lidded Wheelie Bin');
        $mech->content_contains('Blue Recycling Box');
        $mech->content_contains('Monday, 1st April 2024');
        $mech->content_contains('Green Recycling Box');
        $mech->content_contains('Monday, 1st April 2024');
    }

    subtest 'Checking calendar' => sub {
        $mech->follow_link_ok(
            { text => 'Add to your calendar (.ics file)' } );
        $mech->content_contains('BEGIN:VCALENDAR');
        my @events = split /BEGIN:VEVENT/, $mech->encoded_content;
        shift @events; # Header
        my $i = 0;
        for (@events) {
            $i++ if /DTSTART;VALUE=DATE:20240401/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240401/ && /SUMMARY:Green Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240402/ && /SUMMARY:Communal Food Bin/;
            $i++ if /DTSTART;VALUE=DATE:20240403/ && /SUMMARY:Clear Sack\(s\)/;

            $i++ if /DTSTART;VALUE=DATE:20240408/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240408/ && /SUMMARY:Green Recycling Box/;

            $i++ if /DTSTART;VALUE=DATE:20240415/ && /SUMMARY:Blue Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240415/ && /SUMMARY:Green Recycling Box/;
            $i++ if /DTSTART;VALUE=DATE:20240416/ && /SUMMARY:Communal Food Bin/;
            $i++ if /DTSTART;VALUE=DATE:20240417/ && /SUMMARY:Clear Sack\(s\)/;
        }
        my $expected_num = 10;
        is @events, $expected_num, "$expected_num events in calendar";
        is $i, 10, 'Correct events in the calendar';
    };

    subtest 'Correct PDF download link shown' => sub {
        for my $test ({ address => 3, link => 1 }, { address => 4, link => 2 }) {
            $mech->get_ok('/waste');
            $mech->submit_form_ok( { with_fields => { postcode => 'DA1 3LD' } } );
            $mech->submit_form_ok( { with_fields => { address => $test->{address} } } );
            $mech->content_contains('<li><a href="PDF '. $test->{link} . '">Download PDF waste calendar', 'PDF link ' . $test->{link} . ' shown');
        }
    };
};

done_testing;

sub _addresses_for_postcode {

  my $data = shift;

  if ($data->{Postcode} eq 'DA1 3LD') {
    return
    { Addresses =>
      { Address =>
        [
          {
            'SiteShortAddress' => ', 1, THE AVENUE, DA1 3LD',
            'AccountSiteId' => '1',
          },
          {
            'SiteShortAddress' => ', 2, THE AVENUE, DA1 3LD',
            'AccountSiteId' => '2',
          },
        ]
      }
    }
  } elsif ($data->{Postcode} eq 'DA1 3NP') {
    return
    { Addresses => {
        Address =>
          {
            'SiteShortAddress' => ', 1, THE AVENUE, DA1 3NP',
            'AccountSiteId' => '1',
          }
      }
    }
  }
}

sub _site_info {
    return {
        1 => {
            AccountSiteID   => 1,
            AccountSiteUPRN => 10001,
            Site            => {
                SiteShortAddress => ', 1, THE AVENUE, DA1 3NP',
                SiteLatitude     => 51,
                SiteLongitude    => -0.1,
            },
        },
        2 => {
            AccountSiteID   => 2,
            AccountSiteUPRN => 10002,
            Site            => {
                SiteShortAddress => ', 2, THE AVENUE, DA1 3LD',
                SiteLatitude     => 51,
                SiteLongitude    => -0.1,
                SiteParentID     => 101,
            },
        },
        3 => {
            AccountSiteID   => 3,
            AccountSiteUPRN => 10003,
            Site            => {
                SiteShortAddress => ', 3, THE AVENUE, DA1 3LD',
                SiteLatitude     => 51,
                SiteLongitude    => -0.1,
                SiteParentID     => 101,
            },
        },
        4 => {
            AccountSiteID   => 4,
            AccountSiteUPRN => 10004,
            Site            => {
                SiteShortAddress => ', 4, THE AVENUE, DA1 3LD',
                SiteLatitude     => 51,
                SiteLongitude    => -0.1,
                SiteParentID     => 101,
            },
        },

    };
}

sub _account_site_id {
    return {
        AccountSiteID   => 1,
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
                ServiceItemName => 'MDR-SACK', # Clear Sack(s)

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

                NextCollectionDate   => '2024-04-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '0001-01-01T00:00:00',

                RoundSchedule => 'RND-8-9 Mon',
            },
            {   SiteServiceID          => 9,
                ServiceItemDescription => 'Another service (9)',
                ServiceItemName => 'PA-55', # Green Recycling Box

                NextCollectionDate   => '2024-04-01T00:00:00',
                SiteServiceValidFrom => '2024-03-31T00:59:59',
                SiteServiceValidTo   => '0001-01-01T00:00:00',

                RoundSchedule => 'RND-8-9 Mon',
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
    };
}

sub _collection_by_uprn_date {
    return [
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
    ];
}

sub _collection_by_uprn_date_plus {
    return [
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
            Round    => 'RND-6',
            Schedule => 'Wed Wk 2',
            Service  => 'Service 6 Collection',
        },

        {   Date     => '08/04/2024 00:00:00',
            Round    => 'RND-8-9',
            Schedule => 'Mon',
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
            Round    => 'RND-6',
            Schedule => 'Wed Wk 2',
            Service  => 'Service 6 Collection',
        },
    ];
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
    ];
}

sub _worksheet_detail_service_items {
    return {
        2 => [ { ServiceItemName => 'FO-140' } ],
        3 => [],
        4 => [
            { ServiceItemName => 'PC-55' },
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
