use FixMyStreet::Cobrand::Hampshire;
use FixMyStreet::TestMech;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
    BASE_URL => 'http://www.fixmystreet.com',
}, sub {
    my $hampshire = FixMyStreet::Cobrand::Hampshire->new;
    is $hampshire->base_url, 'http://www.fixmystreet.com', "Hampshire returns fixmystreet base_url";
    };

done_testing();
