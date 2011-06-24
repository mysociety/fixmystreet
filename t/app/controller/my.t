use strict;
use warnings;

use Test::More tests => 11;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/my');
is $mech->uri->path, '/auth', "got sent to the sign in page";

# sign in
my $user = $mech->log_in_ok( 'test@example.com' );
$mech->get_ok('/my');
is $mech->uri->path, '/my', "stayed on '/my/' page";

# cleanup
$mech->delete_user( $user );

