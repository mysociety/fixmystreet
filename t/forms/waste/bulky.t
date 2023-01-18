use utf8;
use FixMyStreet::App::Form::Waste::Bulky;
use FixMyStreet::Cobrand::Peterborough;
use FixMyStreet::TestMech;
use Test::MockObject;
use Test::More;

my $mech = FixMyStreet::TestMech->new;

my $req = Test::MockObject->new;
$req->mock( params => sub { {} } );

my $c = Test::MockObject->new;
$c->mock( get_param => sub { "" } );
$c->mock( req => sub {$req} );

# Peterborough
my $body = $mech->create_body_ok(
    2566,
    'Peterborough City Council',
    {},
    {   cobrand           => 'peterborough',
        wasteworks_config => {
            item_list => [
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'Amplifiers',
                    price     => '',
                },
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'DVD/BR Video players',
                    price     => '',
                },
                {   bartec_id => '1001',
                    category  => 'Audio / Visual Elec. equipment',
                    message   => '',
                    name      => 'HiFi Stereos',
                    price     => '',
                },

                {   bartec_id => '1002',
                    category  => 'Baby / Toddler',
                    message   => '',
                    name      => 'Childs bed / cot',
                    price     => '',
                },
                {   bartec_id => '1002',
                    category  => 'Baby / Toddler',
                    message   => '',
                    name      => 'High chairs',
                    price     => '',
                },

                {   bartec_id => '1003',
                    category  => 'Bedroom',
                    message   => '',
                    name      => 'Chest of drawers',
                    price     => '',
                },
                {   bartec_id => '1003',
                    category  => 'Bedroom',
                    message   => 'Please dismantlé',
                    name      => 'Wardrobes',
                    price     => '',
                },
            ],
        },
    },
);
my $cobrand = FixMyStreet::Cobrand::Peterborough->new;
$c->mock( cobrand => sub {$cobrand} );
my $form = FixMyStreet::App::Form::Waste::Bulky->new(
    c         => $c,
    page_name => 'intro',
);

is_deeply $form->items_by_category => {
    'Audio / Visual Elec. equipment' =>
        [ 'Amplifiers', 'DVD/BR Video players', 'HiFi Stereos' ],
    'Baby / Toddler' => [ 'Childs bed / cot', 'High chairs' ],
    'Bedroom'        => [ 'Chest of drawers', 'Wardrobes' ]
};
is_deeply $form->items_extra => { 'Wardrobes' => { message => "Please dismantlé", json => '{"message":"Please dismantlé"}' } };

done_testing;
