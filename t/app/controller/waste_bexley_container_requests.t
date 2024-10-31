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
my $contact_delivery = $mech->create_contact_ok(
    body => $body,
    category => 'Request new container',
    email => 'new@example.org',
    extra => { type => 'waste' },
    group => ['Waste'],
);
my $contact_removal = $mech->create_contact_ok(
    body => $body,
    category => 'Request container removal',
    email => 'new@example.org',
    extra => { type => 'waste' },
    group => ['Waste'],
);
for ( $contact_delivery, $contact_removal ) {
    $_->set_extra_fields(
        {
            code => "uprn",
            required => "false",
            automated => "hidden_field",
        },
        {
            code => "service_item_name",
            required => "false",
            automated => "hidden_field",
        },
        {
            code => "fixmystreet_id",
            required => "true",
            automated => "server_set",
        },
        {
            code => "quantity",
            required => "false",
            automated => "hidden_field",
        },
        {
            code => "assisted_yn",
            required => "false",
            automated => "hidden_field",
        },
    );
    $_->update;
}

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
        household_size_check => 1,
        can_order_lids => 1,

        containers_for_delivery => [
            {   name        => 'Green Wheelie Bin',
                description => 'Non-recyclable waste',
                household_size_check => 1,
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
                description         => 'Food waste',
                service_item_name   => 'FO-23',
                service_id_delivery => '224',
                service_id_removal  => '156',
                max                 => 3,
            },
            {   name                => 'Kitchen Caddy',
                description         => 'Food waste',
                service_item_name   => 'Kitchen 5 Ltr Caddy',
                service_id_delivery => '235',
            },
        ],

        containers_for_removal => [
            {   name        => 'Green Wheelie Bin',
                description => 'Non-recyclable waste',
                household_size_check => 1,
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
                description         => 'Food waste',
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
        'category_delivery' => 'Request new container',
        'category_removal' => 'Request container removal',

        # Delivery
        'bin-size-Green-Wheelie-Bin' => 'RES-140',
        'container-Deliver-Box-lids-55L' => 1,
        'container-FO-23' => 1,
        'container-PC-55' => 0,
        'parent-Green-Wheelie-Bin' => 1,

        'quantity-Deliver-Box-lids-55L' => 3,
        'quantity-FO-23' => 2,

        # Removal
        'container-RES-180-removal' => 1,
        'container-FO-23-removal' => 1,

        'quantity-FO-23-removal' => 2,

        'request_reason' => 'My existing bin is damaged',
    };

    subtest 'waste_munge_request_form_data' => sub {
        $cobrand->waste_munge_request_form_data($data);

        cmp_deeply $data, {
            'category' => 'Request new container',
            'category_delivery' => 'Request new container',
            'category_removal' => 'Request container removal',

            # Delivery
            'bin-size-Green-Wheelie-Bin' => 'RES-140',
            'container-Deliver-Box-lids-55L' => 1,
            'container-FO-23' => 1,
            'container-PC-55' => 0,
            'parent-Green-Wheelie-Bin' => 1,

            'quantity-Deliver-Box-lids-55L' => 3,
            'quantity-FO-23' => 2,

            # Removal
            'container-RES-180-removal' => 1,
            'container-FO-23-removal' => 1,

            'quantity-FO-23-removal' => 2,

            'request_reason' => 'My existing bin is damaged',

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
                containers_for_removal => [
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
                container-FO-23-removal
                container-RES-140
                container-RES-180-removal
            /
        ], 'correct list of services';

        for my $test (
            (   {   id            => 'Deliver-Box-lids-55L',
                    expected_data => {
                        category => 'Request new container',
                        title  => 'Request new Recycling Box Lids',
                        detail => 'Request new Recycling Box Lids

ABC

Reason: My existing bin is damaged

Quantity: 3',
                    },
                    expected_params => {
                        uprn              => 123456,
                        service_item_name => 'Deliver Box lids 55L',
                        quantity          => 3,
                        assisted_yn       => 'No',
                    },
                },
                {   id            => 'FO-23',
                    expected_data => {
                        category => 'Request new container',
                        title  => 'Request new Brown Caddy',
                        detail => 'Request new Brown Caddy

ABC

Reason: My existing bin is damaged

Quantity: 2',
                    },
                    expected_params => {
                        uprn              => 123456,
                        service_item_name => 'FO-23',
                        quantity          => 2,
                        assisted_yn       => 'No',
                    },
                },
                {   id            => 'RES-140',
                    expected_data => {
                        category => 'Request new container',
                        title  => 'Request new Green Wheelie Bin',
                        detail => 'Request new Green Wheelie Bin

ABC

Reason: My existing bin is damaged

Quantity: 1',
                    },
                    expected_params => {
                        uprn              => 123456,
                        service_item_name => 'RES-140',
                        quantity          => 1,
                        assisted_yn       => 'No',
                    },
                },
                {   id            => 'RES-180-removal',
                    expected_data => {
                        category => 'Request container removal',
                        title  => 'Request removal of Green Wheelie Bin',
                        detail => 'Request removal of Green Wheelie Bin

ABC

Reason: My existing bin is damaged

Quantity: 1',
                    },
                    expected_params => {
                        uprn              => 123456,
                        service_item_name => 'RES-180',
                        quantity          => 1,
                        assisted_yn       => 'No',
                    },
                },
                {   id            => 'FO-23-removal',
                    expected_data => {
                        category => 'Request container removal',
                        title  => 'Request removal of Brown Caddy',
                        detail => 'Request removal of Brown Caddy

ABC

Reason: My existing bin is damaged

Quantity: 2',
                    },
                    expected_params => {
                        uprn              => 123456,
                        service_item_name => 'FO-23',
                        quantity          => 2,
                        assisted_yn       => 'No',
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
                'category_delivery' => 'Request new container',
                'category_removal' => 'Request container removal',

                # Delivery
                'bin-size-Green-Wheelie-Bin'     => 'RES-140',
                'container-Deliver-Box-lids-55L' => 1,
                'container-FO-23'                => 1,
                'container-PC-55'                => 0,
                'container-RES-140'              => 1,
                'parent-Green-Wheelie-Bin'       => 1,

                'quantity-Deliver-Box-lids-55L' => 3,
                'quantity-FO-23' => 2,

                # Removal
                'container-RES-180-removal' => 1,
                'container-FO-23-removal' => 1,

                'quantity-FO-23-removal' => 2,

                'request_reason' => 'My existing bin is damaged',

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
        $mech->content_lacks("$removal_string brown wheelie bin");

        $mech->content_contains('Order replacement bins');
        $mech->content_contains('Order removal of old containers');
        $mech->content_contains('Order lids');

        subtest 'Green wheelie bin' => sub {
            $mech->submit_form_ok( { form_id => 'form-RES-180-delivery' } );
            $mech->content_contains(
                'How many people live at the property?',
                'Household size options shown first'
            );

            note 'Choose household size of 2';
            $mech->submit_form_ok( { with_fields => { household_size => 2 } } );
# TODO Green wheelie bin should be pre-checked
            $mech->content_like(
                qr/hidden.*bin-size-Green-Wheelie-Bin.*RES-140/,
                'Hidden single option for bin size' );
            $mech->back;

            note 'Choose household size of 3';
            $mech->submit_form_ok( { with_fields => { household_size => 3 } } );
            $mech->content_like(
                qr/option.*RES-140.*Small 140 litre/,
                'Small bin option',
            );
            $mech->content_like(
                qr/option.*RES-180.*Medium 180 litre/,
                'Medium bin option',
            );
            $mech->content_unlike(
                qr/option.*RES-240.*Large 240 litre/,
                'No big bin option',
            );
            $mech->back;

            note 'Choose household size of 5 or more';
            $mech->submit_form_ok( { with_fields => { household_size => '5 or more' } } );
            $mech->content_like(
                qr/option.*RES-140.*Small 140 litre/,
                'Small bin option',
            );
            $mech->content_like(
                qr/option.*RES-180.*Medium 180 litre/,
                'Medium bin option',
            );
            $mech->content_like(
                qr/option.*RES-240.*Large 240 litre/,
                'Big bin option',
            );
        };

        subtest 'Request multiple containers' => sub {
            $mech->get_ok('/waste/10001');
            $mech->follow_link_ok(
                { text_regex => qr /Order replacement bins/ } );

            $mech->submit_form_ok( { with_fields => { household_size => 3 } },
                'Choose household size' );

            $mech->submit_form_ok(
                {   with_fields => {
                        'parent-Green-Wheelie-Bin'   => 1,
                        'bin-size-Green-Wheelie-Bin' => 'RES-140',

                        'container-PG-55' => 1,

                        'container-Deliver-Box-lids-55L' => 1,
                        'quantity-Deliver-Box-lids-55L'  => 4,

                        'container-FO-23' => 1,
                        'quantity-FO-23'  => 2,

                        'container-Kitchen-5-Ltr-Caddy' => 1,
                    },
                },
            );

            $mech->content_contains(
                'Which containers do you need to be removed?',
                'On removal page' );
            $mech->content_contains('We are unable to collect kitchen caddies',
                'Contains intro text');
            $mech->submit_form_ok( {},
                'can submit removal page with nothing selected' );
            $mech->back;
            $mech->submit_form_ok(
                {   with_fields => {
                        'container-RES-180-removal' => 1,

                        'container-FO-23-removal' => 1,
                        'quantity-FO-23-removal'  => 3,
                    },
                },
                'submit removal page with options selected',
            );

            $mech->submit_form_ok(
                {   with_fields => {
                        request_reason  => 'My existing bin is damaged',
                    }
                },
                'submit reason page',
            );

            $mech->submit_form_ok(
                {   with_fields => {
                        name  => 'Test User',
                        phone => '44 07 111 111 111',
                        email => 'test@example.com'
                    }
                },
                'submit "about you" page',
            );

            $mech->content_contains( 'Please review the information',
                'On summary page' );

            note 'Delivery summary:';
            $mech->content_contains('Green Wheelie Bin (Non-recyclable waste) - Small 140 litre');
            $mech->content_contains('White Recycling Box (Plastics, cans and glass)');
            $mech->content_contains('Recycling Box Lids');
            $mech->content_contains('Brown Caddy (Food waste)');
            $mech->content_like(qr/govuk-summary-list__value.*2/);

            note 'Removal summary:';
            $mech->content_contains('Green Wheelie Bin (Non-recyclable waste) - Medium 180 litre');
            $mech->content_contains('Brown Caddy (Food waste)');
            $mech->content_like(qr/govuk-summary-list__value.*3/);

            $mech->submit_form_ok(
                { with_fields => { submit => 'Request new containers' } } );

            $mech->content_contains( 'Your container request has been sent',
                'Request successful' );

            my $rows = FixMyStreet::DB->resultset("Problem")->order_by('id');
            is $rows->count, 7, 'correct number of reports raised';

            my %extra;
            while ( my $report = $rows->next ) {
                ok $report->confirmed;
                is $report->state, 'confirmed';
                is $report->get_extra_field_value('uprn'), '10001', 'UPRN is correct';
                is $report->get_extra_field_value('assisted_yn'), 'No',
                    'assisted_yn is correct';

                my $category = $report->category;
                $extra{ $category }{ $report->get_extra_field_value('service_item_name') }
                    = $report->get_extra_field_value('quantity');
            }
            cmp_deeply \%extra, {
                'Request new container' => {
                    'RES-140'              => 1,
                    'PG-55'                => 1,
                    'Deliver Box lids 55L' => 4,
                    'FO-23'                => 2,
                    'Kitchen 5 Ltr Caddy'  => 1,
                },
                'Request container removal' => {
                    'RES-180' => 1,
                    'FO-23'   => 3,
                },
            }, 'Extra data is correct';
        };
    };

    subtest 'Above-shop property' => sub {
        $mech->delete_problems_for_body( $body->id );

        $mech->get_ok('/waste/10002');

        $mech->content_contains("$new_string clear sack(s)");
        $mech->content_lacks("$new_string black sack(s)");

        $mech->content_lacks("$removal_string clear sack(s)");
        $mech->content_lacks("$removal_string black sack(s)");

        $mech->content_contains('Order replacement bins');
        $mech->content_lacks('Order removal of old containers');
        $mech->content_lacks('Order lids');

        subtest 'Request sacks' => sub {
            $mech->submit_form_ok( { form_id => 'form-MDR-SACK-delivery' } );

            $mech->submit_form_ok(
                {   with_fields => {
                        'container-MDR-SACK'   => 1,
                    },
                },
            );

            $mech->submit_form_ok(
                {   with_fields => {
                        name  => 'Test User',
                        phone => '44 07 111 111 111',
                        email => 'test@example.com'
                    }
                },
                'submit "about you" page',
            );

            $mech->content_contains( 'Please review the information',
                'On summary page' );

            note 'Delivery summary:';
            $mech->content_contains('Clear Sack(s) (Mixed recycling)');

            $mech->submit_form_ok(
                { with_fields => { submit => 'Request new containers' } } );

            $mech->content_contains( 'Your container request has been sent',
                'Request successful' );

            my $rows = FixMyStreet::DB->resultset("Problem")->order_by('id');
            is $rows->count, 1, 'correct number of reports raised';

            my %extra;
            while ( my $report = $rows->next ) {
                ok $report->confirmed;
                is $report->state, 'confirmed';
                is $report->category, 'Request new container';
                like $report->detail, qr/Reason: I need more sacks/,
                    'Default reason provided';
                is $report->get_extra_field_value('uprn'), '10002', 'UPRN is correct';
                is $report->get_extra_field_value('assisted_yn'), 'No',
                    'assisted_yn is correct';
                $extra{ $report->get_extra_field_value('service_item_name') }
                    = $report->get_extra_field_value('quantity');
            }
            cmp_deeply \%extra, { 'MDR-SACK' => 1 }, 'Extra data is correct';
        };
    };

    subtest 'Removal-only form' => sub {
        $mech->delete_problems_for_body( $body->id );

        $mech->get_ok('/waste/10001');

        $mech->follow_link_ok(
            { text_regex => qr /Order removal/ } );

        $mech->content_contains('We are unable to collect kitchen caddies',
            'Contains intro text');

        $mech->submit_form_ok(
            {   with_fields => {
                    'container-RES-180-removal' => 1,

                    'container-FO-23-removal' => 1,
                    'quantity-FO-23-removal'  => 2,
                },
            },
        );

        $mech->submit_form_ok(
            {   with_fields => {
                    request_reason  => 'My existing bin is damaged',
                }
            },
            'submit reason page',
        );

        $mech->submit_form_ok(
            {   with_fields => {
                    name  => 'Test User',
                    phone => '44 07 111 111 111',
                    email => 'test@example.com',
                }
            },
            'submit "about you" page',
        );

        note 'Removal summary:';
        $mech->content_contains('Green Wheelie Bin (Non-recyclable waste) - Medium 180 litre');
        $mech->content_contains('Brown Caddy (Food waste)');
        $mech->content_like(qr/govuk-summary-list__value.*2/);

        $mech->submit_form_ok(
            { with_fields => { submit => 'Request new containers' } } );

        $mech->content_contains( 'Your container request has been sent',
            'Request successful' );

        my $rows = FixMyStreet::DB->resultset("Problem")->order_by('id');
        is $rows->count, 2, 'correct number of reports raised';

        my %extra;
        while ( my $report = $rows->next ) {
            ok $report->confirmed;
            is $report->state, 'confirmed';
            is $report->category, 'Request container removal';
            is $report->get_extra_field_value('uprn'), '10001', 'UPRN is correct';
            is $report->get_extra_field_value('assisted_yn'), 'No',
                'assisted_yn is correct';
            $extra{ $report->get_extra_field_value('service_item_name') }
                = $report->get_extra_field_value('quantity');
        }
        cmp_deeply \%extra, {
            'RES-180'              => 1,
            'FO-23'                => 2,
        }, 'Extra data is correct';
    };

    subtest 'Open container requests' => sub {
        $whitespace_mock->mock( 'GetSiteWorksheets', sub{ [
            {   WorksheetID         => 'ABC',
                WorksheetStatusName => 'Open',
                WorksheetSubject    => 'Deliver a bin',
                WorksheetStartDate      => '',
                WorksheetEscallatedDate => '',
            },
        ] } );

        my ($open_container_request) = $mech->create_problems_for_body(1, $body->id, 'Request new container', {
            external_id => "Whitespace-ABC",
        });
        $open_container_request->set_extra_fields(
            { name => 'service_item_name', value => 'PG-55' } );
        $open_container_request->update;

        $mech->get_ok('/waste/10001');
        $mech->content_contains("A white recycling box container delivery request has been made");
        $mech->get_ok('/waste/10001/request?request_type=delivery');
        $mech->submit_form_ok({ with_fields => { household_size => 2 } });
        $mech->content_like(qr/name="container-PG-55"[^>]*disabled/, 'PG-55 option is disabled');
        $mech->submit_form_ok( { with_fields => { 'container-Kitchen-5-Ltr-Caddy' => 1 } } );
        $mech->content_unlike(qr/name="container-PG-55-removal"[^>]*disabled/, 'PG-55 option is not disabled for removals');
        $mech->get_ok('/waste/10001/request?request_type=removal');
        $mech->content_unlike(qr/name="container-PG-55-removal"[^>]*disabled/, 'PG-55 removal is not disabled');

        subtest 'Open collection request' => sub {
            $whitespace_mock->mock( 'GetSiteWorksheets', sub{ [
                {   WorksheetID         => 'ABC',
                    WorksheetStatusName => 'Open',
                    WorksheetSubject    => 'Collect a bin',
                    WorksheetStartDate      => '',
                    WorksheetEscallatedDate => '',
                },
            ] } );

            $mech->get_ok('/waste/10001');
            $mech->content_contains("A white recycling box container collection request has been made");
            $mech->get_ok('/waste/10001/request?request_type=delivery');
            $mech->submit_form_ok({ with_fields => { household_size => 2 } });
            $mech->content_unlike(qr/name="container-PG-55"[^>]*disabled/, 'PG-55 option is not disabled');
            $mech->submit_form_ok( { with_fields => { 'container-Kitchen-5-Ltr-Caddy' => 1 } } );
            $mech->content_like(qr/name="container-PG-55-removal"[^>]*disabled/, 'PG-55 option is disabled for removals');
            $mech->get_ok('/waste/10001/request?request_type=removal');
            $mech->content_like(qr/name="container-PG-55-removal"[^>]*disabled/, 'PG-55 option is disabled');
        };
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
