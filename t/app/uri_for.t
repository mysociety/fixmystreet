use strict;
use warnings;

use Test::More;

# FIXME Should this be here? A better way? uri_for varies by map.
use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';
FixMyStreet::Map::set_map_class();

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

my $reh_en_c = FixMyStreet::App->new(
    {
        request => Catalyst::Request->new(
            {
                base => URI->new('http://reportemptyhomes.com/'),
                uri  => URI->new('http://reportemptyhomes.com/test_namespace')
            }
        ),
        namespace => 'test_namespace',
    }
);
$reh_en_c->setup_request();


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
    'http://www.fiksgatami.no/foo?lat=1.23&zoom=3',
    'FiksGataMi url with lat not zoom'
);

like(
    $reh_en_c->uri_for_email( '/foo' ),
    qr{^http://en.},
    'adds en to retain language'
);

# instantiate this here otherwise sets locale to cy and breaks test
# above
my $reh_cy_c = FixMyStreet::App->new(
    {
        request => Catalyst::Request->new(
            {
                base => URI->new('http://cy.reportemptyhomes.com/'),
                uri  => URI->new('http://cy.reportemptyhomes.com/test_namespace')
            }
        ),
        namespace => 'test_namespace',
    }
);
$reh_cy_c->setup_request();

like(
    $reh_cy_c->uri_for_email( '/foo' ),
    qr{^http://cy.},
    'retains language'
);

done_testing();
