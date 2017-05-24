use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council', { id => 2237 });
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

$mech->log_in_ok( $superuser->email );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => [ 'oxfordshire' ],
}, sub {
    subtest 'superuser gets areas listed' => sub {
        $mech->create_body_ok(1234, 'Some Other Council');
        $mech->get_ok('/admin/areastats');
        $mech->content_contains('Oxfordshire County Council', 'Oxfordshire is shown on the page');
        $mech->content_contains('Some Other Council', 'Some other council is shown on the page');
    };

    subtest 'body user gets areas listed' => sub {
        $mech->log_in_ok( $oxfordshireuser->email );
        $mech->get_ok('/admin/areastats');
        is $mech->res->previous->code, 302, "got 302 for redirect";
        is $mech->uri->path, '/admin/areastats/body/2237';
        $mech->content_contains('Trowbridge');
        $mech->content_contains('Bradford-on-Avon');
    };

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
