use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/my');
is $mech->uri->path, '/auth', "got sent to the sign in page";

$mech->create_problems_for_body(1, 1234, 'Test Title');

# sign in
my $user = $mech->log_in_ok( 'test@example.com' );
$mech->get_ok('/my');
is $mech->uri->path, '/my', "stayed on '/my/' page";

# Report listed
$mech->content_contains('Test Title');

# cleanup
$mech->delete_user( $user );
$mech->delete_problems_for_body(1234);
done_testing();
