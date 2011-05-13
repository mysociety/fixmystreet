use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;


$mech->get_ok( '/contact' );
$mech->title_like( qr/Contact Us/ );
$mech->content_contains( "We'd love to hear what you think about this site" );

done_testing();
