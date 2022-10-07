use FixMyStreet::App::Form::Waste::Bulky;
use FixMyStreet::Cobrand::Peterborough;
use Test::MockObject;
use Test::More;

my $req = Test::MockObject->new;
$req->mock( params => sub { {} } );

my $c = Test::MockObject->new;
$c->mock( req => sub {$req} );

# Peterborough
my $cobrand = FixMyStreet::Cobrand::Peterborough->new;
$c->mock( cobrand => sub {$cobrand} );
my $form = FixMyStreet::App::Form::Waste::Bulky->new(
    c         => $c,
    page_name => 'add_items',
);

is_deeply $form->items_by_category => {
    'Audio / Visual Elec. equipment' =>
        [ 'Amplifiers', 'DVD/BR Video players', 'HiFi Stereos' ],
    'Baby / Toddler' => [ 'Childs bed / cot', 'High chairs' ],
    'Bedroom'        => [ 'Chest of drawers', 'Wardrobes' ]
};
is_deeply $form->items_extra_text => { 'Wardrobes' => 'Please dismantle' };

done_testing;
