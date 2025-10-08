package t::Mock::Bexley;

use Test::MockModule;
use Test::MockObject;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use Exporter qw(import);

# Normally don't export a variable, but this is just to
# keep it in scope for the duration of the file
our @EXPORT = qw(%bexley_mocks default_mocks $slots_default);

our %bexley_mocks;

$bexley_mocks{aps} = Test::MockModule->new('Integrations::AccessPaySuite');

$bexley_mocks{addresses} = Test::MockModule->new('BexleyAddresses');
# We don't actually read from the file, so just put anything that is a valid path
$bexley_mocks{addresses}->mock( 'database_file', '/' );

$bexley_mocks{dbi} = Test::MockModule->new('DBI');
$bexley_mocks{dbi}->mock( 'connect', sub {
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
                class => $_[3] == 10001 ? 'RD04' : 'C',
                has_parent => 1,
            };
        }
    } );
    return $dbh;
} );

$bexley_mocks{agile} = Test::MockModule->new('Integrations::Agile');
$bexley_mocks{agile}->mock( 'CustomerSearch', sub { {} } );

my $whitespace_mock = $bexley_mocks{whitespace} = Test::MockModule->new('Integrations::Whitespace');
# This can be called by test files
sub default_mocks {
    $whitespace_mock->mock(
        'GetSiteCollections',
        sub {
            my ( $self, $uprn ) = @_;
            return _site_collections()->{$uprn};
        }
    );
    $whitespace_mock->mock(
        'GetCollectionByUprnAndDatePlus',
        sub {
            my ( $self, $property_id, $from_date, $to_date ) = @_;

            return _collection_by_uprn_date()->{$from_date} // [];
        }
    );
    $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub {
        my ( $self, $usrn ) = @_;
        return _in_cab_logs();
    });
    $bexley_mocks{agile}->mock( 'CustomerSearch', sub { {} } );
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

our $slots_default = [
    { AdHocRoundInstanceID => 1, AdHocRoundInstanceDate => '2025-06-27T00:00:00', SlotsFree => 20 },
    { AdHocRoundInstanceID => 2, AdHocRoundInstanceDate => '2025-06-30T00:00:00', SlotsFree => 20 },
    { AdHocRoundInstanceID => 3, AdHocRoundInstanceDate => '2025-07-04T00:00:00', SlotsFree => 20 },
    { AdHocRoundInstanceID => 4, AdHocRoundInstanceDate => '2025-07-05T00:00:00', SlotsFree => 20 }, # Saturday
    { AdHocRoundInstanceID => 5, AdHocRoundInstanceDate => '2025-07-07T00:00:00', SlotsFree => 0 }, # Ignore
];
$whitespace_mock->mock( 'GetCollectionSlots', sub { $slots_default });

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

                RoundSchedule => 'RND-1 Tue Wk 2',
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
                SiteServiceValidFrom => '2000-03-31T00:59:59', # For garden tests
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
        '2024-03-31T00:00:00' => [
            {   Date     => '01/04/2024 00:00:00',
                Round    => 'RND-8-9',
                Schedule => 'Mon',
                Service  => 'Services 8 & 9 Collection',
            },
            {   Date     => '02/04/2024 00:00:00',
                Round    => 'RND-1',
                Schedule => 'Tue Wk 2',
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
                Schedule => 'Tue Wk 2',
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
                Schedule => 'Tue Wk 2',
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
                Schedule => 'Tue Wk 2',
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

1;
