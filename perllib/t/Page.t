#!/usr/bin/perl -w
#
# Page.t:
# Tests for the Page functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.t,v 1.1 2009-08-25 10:28:50 louise Exp $
#

use strict;
use warnings; 

use Test::More tests => 1;

use FindBin;
use lib "$FindBin::Bin/..";
use lib "$FindBin::Bin/../../../perllib";

BEGIN { use_ok('Page'); }