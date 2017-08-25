use FixMyStreet::Test;

use FixMyStreet::DB;

use_ok 'FixMyStreet::Cobrand';

my $c = FixMyStreet::Cobrand::FixMyStreet->new();

FixMyStreet::DB->resultset('BodyArea')->search( { body_id => 1000 } )->delete;
FixMyStreet::DB->resultset('Body')->search( { name => 'Body of a Thousand' } )->delete;

my $body = FixMyStreet::DB->resultset('Body')->find_or_create({
    id => 1000,
    name => 'Body of a Thousand',
});
my $body_area = $body->body_areas->find_or_create({ area_id => 1000 });

FixMyStreet::override_config {
    MAPIT_TYPES => [ 'LBO' ],
    MAPIT_URL => 'http://mapit.uk/',  # Not actually used as no special casing at present
}, sub {
    is_deeply $c->get_body_sender( $body ), { method => 'Email', contact => undef }, 'defaults to email';
    $body_area->update({ area_id => 2481 }); # Croydon LBO
    is_deeply $c->get_body_sender( $body ), { method => 'Email', contact => undef }, 'still email if London borough';
};

$body->send_method( 'TestMethod' );
is $c->get_body_sender( $body )->{ method }, 'TestMethod', 'uses send_method in preference to London';

$body_area->update({ area_id => 1000 }); # Nothing
is $c->get_body_sender( $body )->{ method }, 'TestMethod', 'uses send_method in preference to Email';

$body_area->delete;
$body->delete;

done_testing();
