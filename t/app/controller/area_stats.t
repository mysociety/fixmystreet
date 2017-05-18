use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council', { id => 2237 });

$mech->log_in_ok( $superuser->email );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => [ 'oxfordshire' ],
}, sub {
    subtest 'gets an area' => sub {
        $mech->get_ok('/admin/areastats/20720', 'Returns OK if area exists');
        $mech->content_contains('Area 20720', 'Area name is shown on the page');

        $mech->get('/admin/areastats/XXX');
        is $mech->status, 404, 'Getting a non-existent area returns 404';
    };
};

END {
    $mech->delete_user( $superuser );
    done_testing();
}
