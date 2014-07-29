use strict;
use warnings;
use DateTime;
use Test::More;
use JSON;

use FixMyStreet;
use FixMyStreet::TestMech;

my $EMAIL = 'seesomething@example.com';

my $mech = FixMyStreet::TestMech->new;
my $user = $mech->create_user_ok( $EMAIL );

my $body = $mech->create_body_ok( 2520, 'Coventry City Council' );
$mech->create_body_ok( 2522, 'Dudley Borough Council' );
$mech->create_body_ok( 2514, 'Birmingham City Council' );
$mech->create_body_ok( 2546, 'Walsall Borough Council' );
$mech->create_body_ok( 2519, 'Wolverhampton City Council' );
$mech->create_body_ok( 2538, 'Solihull Borough Council' );
$mech->create_body_ok( 2535, 'Sandwell Borough Council' );

$user->update({ from_body => $body });

subtest 'admin/stats' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'seesomething' ],
    }, sub {
        my $user = $mech->log_in_ok( $EMAIL );

        $mech->get( '/admin/stats' );
        ok $mech->success or do {
            diag $mech->content;
            diag $mech->status;
        };
    }
};

done_testing;
