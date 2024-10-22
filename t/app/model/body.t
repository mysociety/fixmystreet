use Test::More;

use FixMyStreet;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(163793, 'Buckinghamshire');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {

    subtest "body can have no cobrand" => sub {
        is $body->get_cobrand_handler, undef;
    };

    subtest "body doesn't return cobrand if not allowed" => sub {
        $body->cobrand("buckinghamshire");
        is $body->get_cobrand_handler, undef;
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet', 'buckinghamshire' ],
}, sub {

    subtest "body returns correct cobrand" => sub {
        isa_ok $body->get_cobrand_handler, 'FixMyStreet::Cobrand::Buckinghamshire';
    };
};

done_testing();
