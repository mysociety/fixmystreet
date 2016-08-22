use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/my');
is $mech->uri->path, '/auth', "got sent to the sign in page";

$mech->create_problems_for_body(1, 1234, 'Test Title');
my $other_user = FixMyStreet::DB->resultset('User')->find_or_create({ email => 'another@example.com' });
$mech->create_problems_for_body(1, 1234, 'Another Title', { user => $other_user });

my $user = $mech->log_in_ok( 'test@example.com' );
$mech->get_ok('/my');
is $mech->uri->path, '/my', "stayed on '/my' page";

$mech->content_contains('Test Title');
$mech->content_lacks('Another Title');

done_testing();

END {
    $mech->delete_user($user);
    $mech->delete_user($other_user);
}
