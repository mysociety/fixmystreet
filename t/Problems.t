#!/usr/bin/perl -w
#
# Problem.t:
# Tests for the Problem functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Problems.t,v 1.2 2009-11-12 11:11:02 louise Exp $
#

use strict;
use warnings; 
use Test::More tests => 6;
use Test::Exception; 

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Problems;


