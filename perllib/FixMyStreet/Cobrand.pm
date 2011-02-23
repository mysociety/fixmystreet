# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: evdb@mysociety.org. WWW: http://www.mysociety.org

package FixMyStreet::Cobrand;

use strict;
use warnings;

use Carp;

use Module::Pluggable
  sub_name    => '_cobrands',
  search_path => ['FixMyStreet::Cobrand'],
  require     => 1;

=item get_allowed_cobrands

Return an array reference of allowed cobrand subdomains

=cut

sub get_allowed_cobrands {
    

    my $allowed_cobrand_string = mySociety::Config::get('ALLOWED_COBRANDS');
    my @allowed_cobrands = split( /\|/, $allowed_cobrand_string );
    return \@allowed_cobrands;
}

=item cobrand_handle Q

Given a query that has the name of a site set, return a handle to the Util module for that
site, if one exists, or zero if not.

=cut

sub cobrand_handle {
    my $cobrand = shift;

    our %handles;

    # Once we have a handle defined, return it.
    return $handles{$cobrand} if defined $handles{$cobrand};

    my $cobrand_class = ucfirst($cobrand);
    my $class         = "Cobrands::" . $cobrand_class . "::Util";
    eval "use $class";

    eval { $handles{$cobrand} = $class->new };
    $handles{$cobrand} = 0 if $@;
    return $handles{$cobrand};
}

1;
