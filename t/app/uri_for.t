use FixMyStreet::Test;

use Catalyst::Test 'FixMyStreet::App';

# structure of these tests borrowed from '/t/aggregate/unit_core_uri_for.t'

use strict;
use warnings;
use URI;

my $fms_c = ctx_request('http://www.fixmystreet.com/');

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

done_testing();
