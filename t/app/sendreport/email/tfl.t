use FixMyStreet::SendReport::Email::TfL;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $bromley = $mech->create_body_ok(2482, 'Bromley Council');
my $tfl = $mech->create_body_ok(2482, 'TfL');

$mech->create_contact_ok(email => 'council@example.com', body_id => $bromley->id, category => 'Graffiti');
$mech->create_contact_ok(email => 'council@example.com', body_id => $bromley->id, category => 'Faulty street light');
$mech->create_contact_ok(email => 'tfl@example.com', body_id => $tfl->id, category => 'Traffic lights');

my $row = FixMyStreet::DB->resultset('Problem')->new( {
    bodies_str => '1000',
    category => 'Faulty street light',
    cobrand => '',
} );

my $e = FixMyStreet::SendReport::Email::TfL->new;
is $e->build_recipient_list($row), undef, 'no recipients if no body';

$e = FixMyStreet::SendReport::Email::TfL->new;
$e->add_body($bromley);
is $e->build_recipient_list($row), undef, 'no recipients if category missing';

$e = FixMyStreet::SendReport::Email::TfL->new;
$e->add_body($tfl);
is $e->build_recipient_list($row), 1, 'correct recipient list count';
is_deeply $e->to, [ [ 'tfl@example.com', 'TfL' ] ], 'correct To line';

done_testing();

