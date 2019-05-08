use FixMyStreet::TestMech;

use_ok 'FixMyStreet::Cobrand::Bexley';

my $cobrand = FixMyStreet::Cobrand::Bexley->new;
like $cobrand->contact_email, qr/bexley/;
is $cobrand->on_map_default_status, 'open';
is_deeply $cobrand->disambiguate_location->{bounds}, [ 51.408484, 0.074653, 51.515542, 0.2234676 ];

my $mech = FixMyStreet::TestMech->new;

$mech->create_body_ok(2494, 'London Borough of Bexley');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bexley' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

    subtest 'cobrand displays council name' => sub {
        ok $mech->host("bexley.fixmystreet.com"), "change host to bexley";
        $mech->get_ok('/');
        $mech->content_contains('Bexley');
    };

    subtest 'cobrand displays council name' => sub {
        $mech->get_ok('/reports/Bexley');
        $mech->content_contains('Bexley');
    };

};

done_testing();
