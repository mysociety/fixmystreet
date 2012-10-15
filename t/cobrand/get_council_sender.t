use strict;
use warnings;

use Test::More;

use mySociety::Locale;
use FixMyStreet::App;

use_ok 'FixMyStreet::Cobrand';

mySociety::Locale::gettext_domain( 'FixMyStreet' );

my $c = FixMyStreet::Cobrand::FixMyStreet->new();


is_deeply $c->get_council_sender( '1000', { type => 'DIS' } ), { method => 'Email' }, 'defaults to email';
is_deeply $c->get_council_sender( '1000', { type => 'LBO' } ), { method=> 'London' }, 'returns london report it if London borough';

my $conf = FixMyStreet::App->model('DB::Open311Conf')->find_or_create(
    area_id => 1000,
    endpoint => '',
    send_method => 'TestMethod'
);

is $c->get_council_sender( '1000', { type => 'LBO' } )->{ method }, 'TestMethod', 'uses send_method in preference to London';
is $c->get_council_sender( '1000', { type => 'DIS' } )->{ method }, 'TestMethod', 'uses send_method in preference to Email';

$conf->delete;

done_testing();
