use FixMyStreet::Test;

use FixMyStreet::DB;

use_ok 'FixMyStreet::Cobrand';

my $c = FixMyStreet::Cobrand::FixMyStreet->new();

my $body = FixMyStreet::DB->resultset('Body')->find_or_create({
    id => 1000,
    name => 'Body of a Thousand',
});

my $problem = FixMyStreet::DB->resultset('Problem')->new({});

FixMyStreet::override_config {
    MAPIT_TYPES => [ 'LBO' ],
    MAPIT_URL => 'http://mapit.uk/',  # Not actually used as no special casing at present
}, sub {
    is_deeply $c->get_body_sender( $body, $problem ), { method => 'Email', contact => undef }, 'defaults to email';
};

$body->send_method( 'TestMethod' );
is $c->get_body_sender( $body, $problem )->{ method }, 'TestMethod', 'uses send_method in preference to Email';

done_testing();
