use utf8;

use FixMyStreet::Cobrand::Bexley;
use FixMyStreet::TestMech;
use Test::Deep;

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

done_testing;
