use strict; use warnings;

=head1 NAME

warwick_dbd.t - test that Oracle constants can be imported if present

=cut

use Test::More;

use lib 't/open311/endpoint/exor/';

use DBD::Oracle; # fake from above test lib (or real if installed)
use t::open311::endpoint::Endpoint_Warwick;

ok 1;
done_testing;
