use JSON::MaybeXS;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/mapit/areas/Birmingham');
    is_deeply decode_json($mech->content), {2514 => {parent_area => undef, id => 2514, name => "Birmingham City Council", type => "MTD"}};
};

done_testing;
