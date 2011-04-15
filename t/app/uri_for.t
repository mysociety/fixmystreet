use strict;
use warnings;

use Test::More;

# structure of these tests borrowed from '/t/aggregate/unit_core_uri_for.t'

use strict;
use warnings;
use URI;

use_ok('FixMyStreet::App');

my $fms_c = FixMyStreet::App->new(
    {
        request => Catalyst::Request->new(
            {
                base => URI->new('http://www.fixmystreet.com/'),
                uri  => URI->new('http://www.fixmystreet.com/test_namespace')
            }
        ),
        namespace => 'test_namespace',
    }
);

my $fgm_c = FixMyStreet::App->new(
    {
        request => Catalyst::Request->new(
            {
                base => URI->new('http://www.fiksgatami.no/'),
                uri  => URI->new('http://www.fiksgatami.no/test_namespace')
            }
        ),
        namespace => 'test_namespace',
    }
);

is(
    $fms_c->uri_for('/bar/baz') . "",
    'http://www.fixmystreet.com/bar/baz',
    'URI for absolute path'
);

is(
    $fms_c->uri_for('') . "",
    'http://www.fixmystreet.com/test_namespace',
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
    'http://www.fiksgatami.no/foo?lat=1.23;zoom=2',
    'FiksGataMi url with lat not zoom'
);

## Should really test the cities but we'd need to fake up too much of the
# request. Following code starts to do this but is not complete. Instead better
# to test that the cities produces the correct urls by looking at the html
# produced.
#
# # cities
# my $cities_c = FixMyStreet::App->new(
#     {
#         request => Catalyst::Request->new(
#             {
#                 base => URI->new('http://cities.fixmystreet.com/'),
#                 uri  => URI->new(
#                     'http://cities.fixmystreet.com/test_namespace?city=cardiff'
#                 ),
#                 params => { city => 'cardiff', },
#             }
#         ),
#         namespace => 'test_namespace',
#     }
# )->setup_request;
# is(
#     $cities_c->uri_for( '/foo', { bar => 'baz' } ) . "",
#     '{microapp-href:http://cities.fixmystreet.com/foo?bar=baz&city=cardiff}',
#     'Cities url'
# );

done_testing();
