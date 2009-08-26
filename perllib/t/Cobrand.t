#!/usr/bin/perl -w
#
# Cobrand.t:
# Tests for the cobranding functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Cobrand.t,v 1.2 2009-08-26 17:24:40 louise Exp $
#

use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Cobrand;
use MockQuery;

sub test_cobrand_page{
    my $q  = new MockQuery('mysite');
    # should get the result of the page function in the cobrand module if one exists
    my ($html, $params) = Cobrand::cobrand_page($q);
    like($html, qr/A cobrand produced page/, 'cobrand_page returns output from cobrand module'); 

    # should return 0 if no cobrand module exists
    $q  = new MockQuery('mynonexistingsite');
    ($html, $params) = Cobrand::cobrand_page($q);
    is($html, 0, 'cobrand_page returns 0 if there is no cobrand module'); 
    return 1;

}


ok(test_cobrand_page() == 1, 'Ran all tests for the cobrand_page function');
