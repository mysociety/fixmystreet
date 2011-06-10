#!/usr/bin/env perl

use strict;
use warnings;

use List::MoreUtils 'uniq';

my $root;

BEGIN {    # add the local perllibs too

    # Can't use Path::Class here as we'd load the old debian one.
    $root = __FILE__ =~ m{^(.*)/(web|bin)/\.\..*$} ? $1 : `pwd`;
    chomp($root);
}

# Set the environment for the FixMyStreet project

# Add the lib/perl5 in perl-external so that we can load local::lib from there
use lib "$root/perl-external/lib/perl5";

# Add the perl-external dirs properly using local::lib
use local::lib "$root/perl-external";
use local::lib "$root/perl-external/local-lib";

use lib "$root/commonlib/perllib";
use lib "$root/perllib";
for ( "$root/commonlib/perllib", "$root/perllib" ) {
    $ENV{PERL5LIB} = "$_:$ENV{PERL5LIB}";
}

# also set the path to our scripts etc
$ENV{PATH} = join ':', uniq "$root/bin", split( m/:/, $ENV{PATH} );

# we might want to require this file to configure something like a CGI script
if ( $0 eq __FILE__ ) {

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
else {

    # we were just required - unload some modules to prevent old code
    # getting in the way of loading newer code from the newly set directories.

    # use an eval to prevent needing Class::Unload before perl-external properly
    # setup
    eval "use Class::Unload";
    die $@ if $@;

    my @modules =
      sort
      grep { m/File::/ }
      map { s{\.pm$}{}; s{/}{::}g; $_ }
      grep { m{\.pm$} }
      keys %INC;

    for (@modules) {
        Class::Unload->unload($_);
    }
}

1;

