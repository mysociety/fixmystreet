#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use List::MoreUtils 'uniq';

# Set the environment for the FixMyStreet project

# Add the lii/perl5 in perl-external so that we can load local::lib from there
use lib "$FindBin::Bin/perl-external/lib/perl5";

# Add the perl-external dirs properly using local::lib
use local::lib "$FindBin::Bin/perl-external";
use local::lib "$FindBin::Bin/perl-external/local-lib";

# add the local perllibs too
use lib "$FindBin::Bin/commonlib/perllib";
use lib "$FindBin::Bin/perllib";

# also set the path to our scripts etc
$ENV{PATH} = join ':', uniq "$FindBin::Bin/bin", split( m/:/, $ENV{PATH} );

# now decide what to do  - if no arguments print out shell arguments to set the
# environment. If there are arguments then run those so that they run correctly
if (@ARGV) {
    system @ARGV;
}
else {

    my @keys = sort 'PATH', grep { m{^PERL} } keys %ENV;

    print "export $_='$ENV{$_}'\n" for @keys;
    print 'export PS1="(fms) $PS1"' . "\n";

    print << "STOP";

# $0 - set up the environment for FixMyStreet.
#
# This script can be used one of two ways:
#
# With arguments executes the arguments with the environment correctly set -
# intended for things like the cron jobs:
# 
#   $0 env
#
# Or if no arguments prints out the bash shell commands needed to set up the
# environment - which is useful when developing. Use this to set your current
# shell:
#
#   eval `$0`
STOP

}
