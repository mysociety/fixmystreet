use strict;
use warnings;

use Test::More;

use mySociety::Locale;
use FixMyStreet::App;

use_ok 'FixMyStreet::Cobrand';

mySociety::Locale::gettext_domain( 'FixMyStreet' );

my $c = FixMyStreet::Cobrand::FixMyStreet->new();

FixMyStreet::App->model('DB::BodyArea')->search( { body_id => 1000 } )->delete;
FixMyStreet::App->model('DB::Body')->search( { name => 'Body of a Thousand' } )->delete;

my $body = FixMyStreet::App->model('DB::Body')->find_or_create({
    id => 1000,
    name => 'Body of a Thousand',
});
my $body_area = $body->body_areas->find_or_create({ area_id => 1000 });

FixMyStreet::override_config {
    MAPIT_TYPES => [ 'LBO' ],
    MAPIT_URL => 'http://mapit.mysociety.org/',
}, sub {
    is_deeply $c->get_body_sender( $body ), { method => 'Email' }, 'defaults to email';
    $body_area->update({ area_id => 2481 }); # Croydon LBO
    is_deeply $c->get_body_sender( $body ), { method => 'Email' }, 'still email if London borough';
};

$body->send_method( 'TestMethod' );
is $c->get_body_sender( $body )->{ method }, 'TestMethod', 'uses send_method in preference to London';

$body_area->update({ area_id => 1000 }); # Nothing
is $c->get_body_sender( $body )->{ method }, 'TestMethod', 'uses send_method in preference to Email';

$body_area->delete;
$body->delete;

done_testing();
