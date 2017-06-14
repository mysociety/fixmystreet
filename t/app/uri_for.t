use FixMyStreet::Test;

# FIXME Should this be here? A better way? uri_for varies by map.
use Catalyst::Test 'FixMyStreet::App';
FixMyStreet::Map::set_map_class();

# structure of these tests borrowed from '/t/aggregate/unit_core_uri_for.t'

use strict;
use warnings;
use URI;

use_ok('FixMyStreet::App');

my $fms_c = ctx_request('http://www.fixmystreet.com/');
my $fgm_c = ctx_request('http://www.fiksgatami.no/');

is(
    $fms_c->uri_for('/bar/baz') . "",
    'http://www.fixmystreet.com/bar/baz',
    'URI for absolute path'
);

is(
    $fms_c->uri_for('') . "",
    'http://www.fixmystreet.com/',
    'URI for namespace'
);

is(
    $fms_c->uri_for( '/bar/baz', 'boing', { foo => 'bar', } ) . "",
    'http://www.fixmystreet.com/bar/baz/boing?foo=bar',
    'URI with query'
);

# fiksgatami
is(
    $fgm_c->uri_for( '/foo', { lat => 1.23, } ) . "",
    'http://www.fiksgatami.no/foo?lat=1.23&zoom=3',
    'FiksGataMi url with lat not zoom'
);

done_testing();
