use strict;
use warnings;

use Test::More;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/tilma/tileserver/10k-full/3278-3283,1110-1115/JSON');
is $mech->res->content_type, 'text/javascript', "got JS response";

done_testing();