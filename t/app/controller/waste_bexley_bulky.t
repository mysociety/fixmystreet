use Test::MockModule;
use Test::MockObject;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok( 2494, 'Bexley Council', { cobrand => 'bexley' } );
my $user = $mech->create_user_ok( 'bob@example.org', name => 'Original Name' );

for ($body) {
    add_extra_metadata($_);
    create_contact($_);
}

my $addr_mock = Test::MockModule->new('BexleyAddresses');
# We don't actually read from the file, so just put anything that is a valid path
$addr_mock->mock( 'database_file', '/' );
my $dbi_mock = Test::MockModule->new('DBI');
$dbi_mock->mock( 'connect', sub {
    my $dbh = Test::MockObject->new;
    $dbh->mock( 'selectall_arrayref', sub { [
        {   uprn              => 10001,
            pao_start_number  => 1,
            street_descriptor => 'THE AVENUE',
        },
        {   uprn              => 10002,
            pao_start_number  => 2,
            street_descriptor => 'THE AVENUE',
        },
    ] } );
    $dbh->mock( 'selectrow_hashref', sub { {
        postcode => 'DA1 1AA',
        has_parent => 0,
        class => $_[3] == 10001 ? 'RD04' : 'C',
        pao_start_number => 1,
        street_descriptor => 'Test Street',
        town_name => 'Bexley',
    } } );
    return $dbh;
} );

my $whitespace_mock = Test::MockModule->new('Integrations::Whitespace');
sub default_mocks {
    $whitespace_mock->mock('GetSiteCollections', sub {
        [ {
            SiteServiceID          => 1,
            ServiceItemDescription => 'Non-recyclable waste',
            ServiceItemName => 'RES-180',
            ServiceName          => 'Green Wheelie Bin',
            NextCollectionDate   => '2024-02-07T00:00:00',
            SiteServiceValidFrom => '2000-01-01T00:00:00',
            SiteServiceValidTo   => '0001-01-01T00:00:00',
            RoundSchedule => 'RND-1 Mon',
        } ];
    });
    $whitespace_mock->mock(
        'GetCollectionByUprnAndDate',
        sub {
            my ( $self, $property_id, $from_date ) = @_;
            return [];
        }
    );
    $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub { });
    $whitespace_mock->mock( 'GetInCabLogsByUprn', sub { });
    $whitespace_mock->mock( 'GetSiteInfo', sub { {
        AccountSiteID   => 1,
        AccountSiteUPRN => 10001,
        Site            => {
            SiteShortAddress => ', 1, THE AVENUE, DA1 3NP',
            SiteLatitude     => 51.466707,
            SiteLongitude    => 0.181108,
        },
    } });
    $whitespace_mock->mock( 'GetSiteWorksheets', sub {});
};

default_mocks();

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'bexley',
    COBRAND_FEATURES => {
        waste => { bexley => 1 },
        whitespace => { bexley => { url => 'http://example.org/' } },
        waste_features => {
            bexley => {
                bulky_enabled => 1,
                bulky_multiple_bookings => 1,
                bulky_tandc_link => 'tandc_link',
            },
        },
        payment_gateway => { bexley => {
            cc_url => 'http://example.com',
            hmac => '1234',
            hmac_id => '1234',
            scpID => '1234',
        } },
    },
}, sub {
    subtest 'Ineligible property as no bulky service' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '10002' } } );
        $mech->content_lacks('Bulky waste');
    };

    subtest 'Should be eligible property as has bulky service' => sub {
        $mech->get_ok('/waste');
        $mech->submit_form_ok( { with_fields => { postcode => 'DA1 1AA' } } );
        $mech->submit_form_ok( { with_fields => { address => '10001' } } );

        $mech->content_contains('Bulky waste');
        $mech->submit_form_ok({ form_number => 3 });
        $mech->content_contains( 'Before you start your booking',
            'Should be able to access the booking form' );
    };

    my $report;
    subtest 'Bulky goods collection booking' => sub {
        $mech->get_ok('/waste/10001/bulky');

        subtest 'Intro page' => sub {
            $mech->content_contains('Book a bulky waste collection');
            $mech->content_contains('Before you start your booking');
            $mech->content_contains('Prices start from £45.50');
            $mech->submit_form_ok;
        };
    };
};

done_testing;

sub add_extra_metadata {
    my $body = shift;

    $body->set_extra_metadata(
        wasteworks_config => {
            per_item_min_collection_price => 4550,
            show_location_page => 'users',
            item_list => [
                { bartec_id => '83', name => 'Bath', points => 4 },
                { bartec_id => '84', name => 'Bathroom Cabinet /Shower Screen', points => 3 },
                { bartec_id => '85', name => 'Bicycle', points => 3 },
                { bartec_id => '3', name => 'BBQ', points => 2 },
                { bartec_id => '6', name => 'Bookcase, Shelving Unit', points => 1 },
            ],
        },
    );
    $body->update;
}

sub create_contact {
    my ($body) = @_;
    my ($params, @extra) = &_contact_extra_data;

    my $contact = $mech->create_contact_ok(body => $body, %$params, group => ['Waste'], extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        { code => 'fixmystreet_id', required => 1, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

sub _contact_extra_data {
    return (
        { category => 'Bulky collection', email => 'bulky@test.com' },
        { code => 'payment' },
        { code => 'payment_method' },
        { code => 'collection_date' },
        { code => 'bulky_items' },
    );
}
