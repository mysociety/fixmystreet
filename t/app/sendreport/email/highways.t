use FixMyStreet::SendReport::Email::Highways;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $bromley = $mech->create_body_ok(2482, 'Bromley Council');
my $highways = $mech->create_body_ok(2482, 'Highways England');

$mech->create_contact_ok(email => 'council@example.com', body_id => $bromley->id, category => 'Graffiti');
$mech->create_contact_ok(email => 'council@example.com', body_id => $bromley->id, category => 'Faulty street light');
$mech->create_contact_ok(email => 'highways@example.com', body_id => $highways->id, category => 'Pothole');

my $row = FixMyStreet::DB->resultset('Problem')->new( {
    id => 123,
    bodies_str => '1000',
    category => 'Pothole',
    cobrand => '',
} );

my $e = FixMyStreet::SendReport::Email::Highways->new;
is $e->build_recipient_list($row), undef, 'no recipients if no body';

$e = FixMyStreet::SendReport::Email::Highways->new;
$e->add_body($bromley);
is $e->build_recipient_list($row), undef, 'no recipients if category missing';

$e = FixMyStreet::SendReport::Email::Highways->new;
$e->add_body($highways);
is $e->build_recipient_list($row), 1, 'correct recipient list count';
is_deeply $e->to, [ [ 'highways@example.com', 'Highways England' ] ], 'correct To line';

$row->set_extra_fields( { name => 'area_name', value => 'Area 6' } );
is $e->build_recipient_list($row), 1, 'correct recipient list count';
is_deeply $e->to, [ [ 'highways@example.com', 'Highways England' ] ], 'correct To line';

FixMyStreet::override_config {
    COBRAND_FEATURES => { open311_email => { highwaysengland => { area_seven => 'a7@example.com' } } }
}, sub {
    $row->set_extra_fields( { name => 'area_name', value => 'Area 7' } );
    is $e->build_recipient_list($row), 1, 'correct recipient list count';
    is_deeply $e->to, [ [ 'a7@example.com', 'Highways England' ] ], 'correct To line';
};

done_testing();

