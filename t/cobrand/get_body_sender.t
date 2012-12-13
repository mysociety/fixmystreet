use strict;
use warnings;

use Test::More;

use mySociety::Locale;
use FixMyStreet::App;

use_ok 'FixMyStreet::Cobrand';

mySociety::Locale::gettext_domain( 'FixMyStreet' );

my $c = FixMyStreet::Cobrand::FixMyStreet->new();

FixMyStreet::App->model('DB::Body')->search( { name => 'Body of a Thousand' } )->delete;

my $body = FixMyStreet::App->model('DB::Body')->find_or_create({
    area_id => 1000,
    name => 'Body of a Thousand',
});
is_deeply $c->get_body_sender( $body ), { method => 'Email' }, 'defaults to email';

$body->area_id( 2481 ); # Croydon LBO
is_deeply $c->get_body_sender( $body ), { method => 'London' }, 'returns london report it if London borough';

$body->send_method( 'TestMethod' );
is $c->get_body_sender( $body )->{ method }, 'TestMethod', 'uses send_method in preference to London';

$body->area_id( 1000 ); # Nothing
is $c->get_body_sender( $body )->{ method }, 'TestMethod', 'uses send_method in preference to Email';

$body->delete;

done_testing();
