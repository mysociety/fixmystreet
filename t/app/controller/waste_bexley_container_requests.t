use utf8;

use FixMyStreet::Cobrand::Bexley;
use FixMyStreet::TestMech;
use Test::Deep;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST

my $addr_mock = Test::MockModule->new('BexleyAddresses');
# We don't actually read from the file, so just put anything that is a valid path
$addr_mock->mock( 'database_file', '/' );
my $dbi_mock = Test::MockModule->new('DBI');
$dbi_mock->mock( 'connect', sub {
    my $dbh = Test::MockObject->new;
    $dbh->mock( 'selectrow_hashref', sub { {} } );
    return $dbh;
} );

my $mech = FixMyStreet::TestMech->new;

my $cobrand = FixMyStreet::Cobrand::Bexley->new;

subtest '_set_request_containers' => sub {
    my @services = (
        # Wheelie bins
        {   service_name   => 'Green Wheelie Bin',
            service_id     => 'RES-140',
            round_schedule => 'RES-R3 Mon Wk 2',
        },
        {   service_name   => 'Blue Lidded Wheelie Bin',
            service_id     => 'PC-180',
            round_schedule => 'RCY-R15 Mon PC Wk 2',
        },
        {   service_name   => 'White Lidded Wheelie Bin',
            service_id     => 'PG-240',
            round_schedule => 'RCY-R15 Mon PG Wk 2',
        },

        # Recycling boxes
        {   service_name   => 'Black Recycling Box',
            service_id     => 'GL-55',
            round_schedule => 'GP-BOX Wed',
        },
        {   service_name   => 'Green Recycling Box',
            service_id     => 'PA-55',
            round_schedule => 'PFR-BOX Wed',
        },
        {   service_name   => 'Blue Recycling Box',
            service_id     => 'PC-55',
            round_schedule => 'PFR-BOX Mon',
        },

        # Sacks
        {   service_name   => 'Black Sack(s)',
            service_id     => 'RES-SACK',
            round_schedule => 'RES-R8 Thu',
        },
        {   service_name   => 'Clear Sack(s)',
            service_id     => 'MDR-SACK',
            round_schedule => 'MDR-R1 Thu',
        },

        # Food caddy
        {   service_name   => 'Brown Caddy',
            service_id     => 'FO-23',
            round_schedule => 'PFR-BOX Wed',
        },

        # Garden waste
        {   service_name   => 'Brown Wheelie Bin',
            service_id     => 'GA-240',
            round_schedule => 'GDN-R5 Wed GDN Wk 2',
        },
    );

    my $property = {};

    $cobrand->_set_request_containers( $property, @services );

    my %expected_permissions = (
        # [ delivery, removal ]
        'Green Wheelie Bin'        => [ 1, 1 ],
        'Blue Lidded Wheelie Bin'  => [ 1, 1 ],
        'White Lidded Wheelie Bin' => [ 1, 1 ],

        'Black Recycling Box' => [ 0, 1 ],
        'Green Recycling Box' => [ 0, 1 ],
        'Blue Recycling Box'  => [ 1, 1 ],

        'Black Sack(s)' => [ 0, 0 ],
        'Clear Sack(s)' => [ 1, 0 ],

        'Brown Caddy' => [ 1, 1 ],

        'Brown Wheelie Bin' => [ 0, 0 ],
    );
    for (@services) {
        note 'Checking permissions for ' . $_->{service_name};
        is $_->{delivery_allowed} // 0,
            $expected_permissions{ $_->{service_name} }[0];
        is $_->{removal_allowed} // 0,
            $expected_permissions{ $_->{service_name} }[1];
    }

    note 'Checking containers set on property';
    cmp_deeply $property, {
        can_order_lids => 1,

        containers_for_delivery => [
            {   name        => 'Green Wheelie Bin',
                description => 'Non-recyclable waste',
                subtypes    => [
                    {   size                => 'Small 140 litre',
                        service_item_name   => 'RES-140',
                        service_id_delivery => '272',
                        service_id_removal  => '205',
                    },
                    {   size                => 'Medium 180 litre',
                        service_item_name   => 'RES-180',
                        service_id_delivery => '273',
                        service_id_removal  => '206',
                    },
                    {   size                => 'Large 240 litre',
                        service_item_name   => 'RES-240',
                        service_id_delivery => '274',
                        service_id_removal  => '207',
                    },
                ],
            },
            {   name        => 'Blue Lidded Wheelie Bin',
                description => 'Paper and card',
                subtypes    => [
                    {   size                => 'Small 140 litre',
                        service_item_name   => 'PC-140',
                        service_id_delivery => '325',
                        service_id_removal  => '333',
                    },
                    {   size                => 'Medium 180 litre',
                        service_item_name   => 'PC-180',
                        service_id_delivery => '326',
                        service_id_removal  => '334',
                    },
                    {   size                => 'Large 240 litre',
                        service_item_name   => 'PC-240',
                        service_id_delivery => '327',
                        service_id_removal  => '335',
                    },
                ],
            },
            {   name        => 'White Lidded Wheelie Bin',
                description => 'Plastics, cans and glass',
                subtypes    => [
                    {   size                => 'Small 140 litre',
                        service_item_name   => 'PG-140',
                        service_id_delivery => '329',
                        service_id_removal  => '337',
                    },
                    {   size                => 'Medium 180 litre',
                        service_item_name   => 'PG-180',
                        service_id_delivery => '330',
                        service_id_removal  => '338',
                    },
                    {   size                => 'Large 240 litre',
                        service_item_name   => 'PG-240',
                        service_id_delivery => '331',
                        service_id_removal  => '339',
                    },
                ],
            },

            {   name                => 'White Recycling Box',
                description         => 'Plastics, cans and glass',
                service_item_name   => 'PG-55',
                service_id_delivery => '328',
                service_id_removal  => '336',
            },
            {   name                => 'Blue Recycling Box',
                description         => 'Paper and card',
                service_item_name   => 'PC-55',
                service_id_delivery => '324',
                service_id_removal  => '332',
            },
            {   name                => 'Recycling Box Lids',
                service_item_name   => 'Deliver Box lids 55L',
                service_id_delivery => '216',
                max                 => 5,
            },

            {   name                => 'Clear Sack(s)',
                description         => 'Mixed recycling',
                service_item_name   => 'MDR-SACK',
                service_id_delivery => '243',
            },

            {   name                => 'Brown Caddy',
                service_item_name   => 'FO-23',
                service_id_delivery => '224',
                service_id_removal  => '156',
                max                 => 3,
            },
            {   name                => 'Kitchen Caddy',
                service_item_name   => 'Kitchen 5 Ltr Caddy',
                service_id_delivery => '235',
            },
        ],

        containers_for_removal => [
            {   name        => 'Green Wheelie Bin',
                description => 'Non-recyclable waste',
                subtypes    => [
                    {   size                => 'Small 140 litre',
                        service_item_name   => 'RES-140',
                        service_id_delivery => '272',
                        service_id_removal  => '205',
                    },
                    {   size                => 'Medium 180 litre',
                        service_item_name   => 'RES-180',
                        service_id_delivery => '273',
                        service_id_removal  => '206',
                    },
                    {   size                => 'Large 240 litre',
                        service_item_name   => 'RES-240',
                        service_id_delivery => '274',
                        service_id_removal  => '207',
                    },
                ],
            },
            {   name        => 'Blue Lidded Wheelie Bin',
                description => 'Paper and card',
                subtypes    => [
                    {   size                => 'Small 140 litre',
                        service_item_name   => 'PC-140',
                        service_id_delivery => '325',
                        service_id_removal  => '333',
                    },
                    {   size                => 'Medium 180 litre',
                        service_item_name   => 'PC-180',
                        service_id_delivery => '326',
                        service_id_removal  => '334',
                    },
                    {   size                => 'Large 240 litre',
                        service_item_name   => 'PC-240',
                        service_id_delivery => '327',
                        service_id_removal  => '335',
                    },
                ],
            },
            {   name        => 'White Lidded Wheelie Bin',
                description => 'Plastics, cans and glass',
                subtypes    => [
                    {   size                => 'Small 140 litre',
                        service_item_name   => 'PG-140',
                        service_id_delivery => '329',
                        service_id_removal  => '337',
                    },
                    {   size                => 'Medium 180 litre',
                        service_item_name   => 'PG-180',
                        service_id_delivery => '330',
                        service_id_removal  => '338',
                    },
                    {   size                => 'Large 240 litre',
                        service_item_name   => 'PG-240',
                        service_id_delivery => '331',
                        service_id_removal  => '339',
                    },
                ],
            },

            {   name               => 'Green Recycling Box',
                description        => 'Paper and card',
                service_item_name  => 'PA-55',
                service_id_removal => '181',
            },
            {   name               => 'Black Recycling Box',
                description        => 'Glass bottles and jars',
                service_item_name  => 'GL-55',
                service_id_removal => '166',
            },
            {   name                => 'Blue Recycling Box',
                description         => 'Paper and card',
                service_item_name   => 'PC-55',
                service_id_delivery => '324',
                service_id_removal  => '332',
            },

            {   name                => 'Brown Caddy',
                service_item_name   => 'FO-23',
                service_id_delivery => '224',
                service_id_removal  => '156',
                max                 => 3,
            },
        ],
    };

    subtest 'with no services' => sub {
        my @services = ();
        my $property = {};

        $cobrand->_set_request_containers( $property, @services );

        cmp_deeply $property, {
            containers_for_delivery => [],
            containers_for_removal  => [],
        }, 'nothing set on property';
    };
};

subtest 'Munge data' => sub {
    my $data = {
        'category' => 'Request new container',

        'bin-size-Green-Wheelie-Bin' => 'RES-140',
        'container-Deliver-Box-lids-55L' => 1,
        'container-FO-23' => 1,
        'container-PC-55' => 0,
        'parent-Green-Wheelie-Bin' => 1,

        'quantity-Deliver-Box-lids-55L' => 3,
        'quantity-FO-23' => 2,
    };

    subtest 'waste_munge_request_form_data' => sub {
        $cobrand->waste_munge_request_form_data($data);

        cmp_deeply $data, {
            'category' => 'Request new container',

            'bin-size-Green-Wheelie-Bin' => 'RES-140',
            'container-Deliver-Box-lids-55L' => 1,
            'container-FO-23' => 1,
            'container-PC-55' => 0,
            'parent-Green-Wheelie-Bin' => 1,

            'quantity-Deliver-Box-lids-55L' => 3,
            'quantity-FO-23' => 2,

            # New
            'container-RES-140' => 1,
        }, 'data munged from parent container options';
    };

    subtest 'waste_munge_request_data' => sub {
        my %c_params;
        $cobrand->{c} = Test::MockObject->new;
        $cobrand->{c}->mock( set_param => sub { {
            $c_params{$_[1]} = $_[2];
        } } );
        $cobrand->{c}->mock( get_param => sub { {
            $c_params{$_[1]};
        } } );
        $cobrand->{c}->mock( stash => sub { {
            property =>  {
                address => 'ABC',
                uprn => 123456,
                containers_for_delivery => [
                    {   name                => 'Recycling Box Lids',
                        service_item_name   => 'Deliver Box lids 55L',
                        service_id_delivery => '216',
                    },
                    {   name                => 'Brown Caddy',
                        service_item_name   => 'FO-23',
                        service_id_delivery => '224',
                        service_id_removal  => '156',
                    },
                    {   name        => 'Green Wheelie Bin',
                        description => 'Non-recyclable waste',
                        subtypes    => [
                            {   size                => 'Small 140 litre',
                                service_item_name   => 'RES-140',
                                service_id_delivery => '272',
                                service_id_removal  => '205',
                            },
                            {   size                => 'Medium 180 litre',
                                service_item_name   => 'RES-180',
                                service_id_delivery => '273',
                                service_id_removal  => '206',
                            },
                            {   size                => 'Large 240 litre',
                                service_item_name   => 'RES-240',
                                service_id_delivery => '274',
                                service_id_removal  => '207',
                            },
                        ],
                    },
                ],
            }
        } } );

        my @services = grep { /^container-/ && $data->{$_} } sort keys %$data;

        cmp_deeply \@services, [
            qw/
                container-Deliver-Box-lids-55L
                container-FO-23
                container-RES-140
            /
        ], 'correct list of services';

        for my $test (
            (   {   id            => 'Deliver-Box-lids-55L',
                    expected_data => {
                        title  => 'Request new Recycling Box Lids',
                        detail => 'Request new Recycling Box Lids

ABC

Reason: TODO

Quantity: 3',
                    },
                    expected_params => {
                        uprn              => 123456,
                        service_item_name => 'Deliver Box lids 55L',
                        quantity          => 3,
                    },
                },
                {   id            => 'FO-23',
                    expected_data => {
                        title  => 'Request new Brown Caddy',
                        detail => 'Request new Brown Caddy

ABC

Reason: TODO

Quantity: 2',
                },
                    expected_params => {
                        uprn              => 123456,
                        service_item_name => 'FO-23',
                        quantity          => 2,
                    },
                },
                {   id            => 'RES-140',
                    expected_data => {
                        title  => 'Request new Green Wheelie Bin',
                        detail => 'Request new Green Wheelie Bin

ABC

Reason: TODO

Quantity: 1',
                },
                    expected_params => {
                        uprn              => 123456,
                        service_item_name => 'RES-140',
                        quantity          => 1,
                    },
                },
            )
        ) {
            note "For $test->{id}";
            $cobrand->waste_munge_request_data( $test->{id}, $data );

            for ( keys %{ $test->{expected_params} } ) {
                is $cobrand->{c}->get_param($_),
                    $test->{expected_params}{$_}, "param $_ set";
            }

            cmp_deeply $data, {
                'category'                       => 'Request new container',

                'bin-size-Green-Wheelie-Bin'     => 'RES-140',
                'container-Deliver-Box-lids-55L' => 1,
                'container-FO-23'                => 1,
                'container-PC-55'                => 0,
                'container-RES-140'              => 1,
                'parent-Green-Wheelie-Bin'       => 1,

                'quantity-Deliver-Box-lids-55L' => 3,
                'quantity-FO-23' => 2,

                # New
                %{ $test->{expected_data} },
            }, 'new fields set on data';
        }
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        waste      => { bexley => 1 },
        whitespace => { bexley => { url => 'http://example.org/' } },
    },
}, sub {
    my $mech = FixMyStreet::TestMech->new;
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
    $whitespace_mock->mock( 'GetSiteWorksheets', sub{ [] } );
    $whitespace_mock->mock( 'GetCollectionByUprnAndDate', sub{ [] } );
    $whitespace_mock->mock( 'GetInCabLogsByUsrn', sub { [] } );
    $whitespace_mock->mock( 'GetInCabLogsByUprn', sub { [] } );

    my $new_string = 'Request a new or replacement';
    my $removal_string = 'Request removal of a';

    subtest 'Standard non-communal property' => sub {
        $mech->get_ok('/waste/10001');

        $mech->content_contains("$new_string green wheelie bin");
        $mech->content_contains("$new_string blue lidded wheelie bin");
        $mech->content_contains("$new_string white recycling box");
        $mech->content_contains("$new_string brown caddy");
        $mech->content_lacks("$new_string maroon recycling box");
        $mech->content_lacks("$new_string brown wheelie bin");

        $mech->content_contains("$removal_string green wheelie bin");
        $mech->content_contains("$removal_string blue lidded wheelie bin");
        $mech->content_contains("$removal_string white recycling box");
        $mech->content_contains("$removal_string brown caddy");
        $mech->content_contains("$removal_string maroon recycling box");
        $mech->content_lacks("$new_string brown wheelie bin");

        $mech->content_contains('Order replacement bins');
        $mech->content_contains('Order removal of old containers');
        $mech->content_contains('Order lids');
    };

    subtest 'Above-shop property' => sub {
        $mech->get_ok('/waste/10002');

        $mech->content_contains("$new_string clear sack(s)");
        $mech->content_lacks("$new_string black sack(s)");

        $mech->content_lacks("$removal_string clear sack(s)");
        $mech->content_lacks("$removal_string black sack(s)");

        $mech->content_contains('Order replacement bins');
        $mech->content_lacks('Order removal of old containers');
        $mech->content_lacks('Order lids');
    };

};

sub _site_info {
    return {
        10001 => {
            AccountSiteUPRN => 10001,
            Site            => {
                SiteLatitude     => 51.466707,
                SiteLongitude    => 0.181108,
            },
        },
        10002 => {
            AccountSiteUPRN => 10002,
            Site            => {
                SiteLatitude     => 51.466707,
                SiteLongitude    => 0.181108,
            },
        },
    };
}

sub _site_collections {
    my %defaults = (
        NextCollectionDate   => '2024-04-01T00:00:00',
        SiteServiceValidFrom => '2024-03-01T00:59:59',
        SiteServiceValidTo   => '0001-01-01T00:00:00',

        RoundSchedule => 'RND-1 Mon',
    );

    return {
        10001 => [
            {
                ServiceItemName => 'RES-180', # Green Wheelie Bin
                %defaults,
            },
            {
                ServiceItemName => 'PC-180', # Blue Lidded Wheelie Bin
                %defaults,
            },
            {
                ServiceItemName => 'PL-55', # Maroon Recycling Box
                %defaults,
                RoundSchedule => 'PFR-BOX Mon',
            },
            {
                ServiceItemName => 'PG-55', # White Recycling Box
                %defaults,
                RoundSchedule => 'PFR-BOX Mon',
            },
            {
                ServiceItemName => 'FO-23', # Brown Caddy
                %defaults,
            },
            {
                ServiceItemName => 'GA-240', # Brown Wheelie Bin (for garden waste)
                %defaults,
            },
        ],
        10002 => [
            {
                ServiceItemName => 'MDR-SACK', # Clear Sack(s)
                %defaults,
            },
            {
                ServiceItemName => 'RES-SACK', # Black Sack(s)
                %defaults,
            },
        ],
    };
};

done_testing;
