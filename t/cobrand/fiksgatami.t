use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $oslo = $mech->create_body_ok(3, 'Oslo');
my $vestfold = $mech->create_body_ok(7, 'Vestfold');
my $larvik = $mech->create_body_ok(709, 'Larvik');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fiksgatami',
    MAPIT_URL => 'http://mapit.uk/',
    GEOCODER => '',
}, sub {
    $mech->get_ok('/alert/list?pc=0045');
    $mech->content_contains('rss/l/59.9,10.9/2');
    $mech->content_contains('/rss/reports/Oslo');
    $mech->content_contains('council:' . $oslo->id . ':Oslo');

    $mech->get_ok('/alert/list?pc=3290');
    $mech->content_contains('rss/l/59,10/5');
    $mech->content_contains('/rss/area/Larvik');
    $mech->content_contains('/rss/area/Vestfold');
    $mech->content_contains('/rss/reports/Larvik');
    $mech->content_contains('/rss/reports/Vestfold');
    $mech->content_contains('area:7:Vestfold');
    $mech->content_contains('area:709:Larvik');
    $mech->content_contains('council:' . $vestfold->id . ':Vestfold');
    $mech->content_contains('council:' . $larvik->id . ':Larvik');
};

done_testing();
