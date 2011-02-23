# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: evdb@mysociety.org. WWW: http://www.mysociety.org

package FixMyStreet::Cobrand;

use strict;
use warnings;

use FixMyStreet;
use Carp;

use Module::Pluggable
  sub_name    => '_cobrands',
  search_path => ['FixMyStreet::Cobrand'],
  require     => 1;

my @ALL_COBRAND_CLASSES = __PACKAGE__->_cobrands;

=head2 get_allowed_cobrands

Return an array reference of allowed cobrand subdomains

=cut

sub get_allowed_cobrands {
    my $allowed_cobrand_string = FixMyStreet->config('ALLOWED_COBRANDS');
    my @allowed_cobrands = split( /\|/, $allowed_cobrand_string );
    return \@allowed_cobrands;
}

=head2 available_cobrand_classes

    @available_cobrand_classes =
      FixMyStreet::Cobrand->available_cobrand_classes();

Return an array of all the classes that were found and that have monikers that
match the values from get_allowed_cobrands.

=cut

sub available_cobrand_classes {
    my $class = shift;

    my %allowed = map { $_ => 1 } @{ $class->get_allowed_cobrands };
    my @avail = grep { $allowed{ $_->moniker } } @ALL_COBRAND_CLASSES;

    return @avail;
}

=head2 get_class_for_host

    $cobrand_class = FixMyStreet::Cobrand->get_class_for_host( $host );

Given a host determine which cobrand we should be using. 

=cut

sub get_class_for_host {
    my $class = shift;
    my $host  = shift;

    foreach my $avail ( $class->available_cobrand_classes ) {
        my $moniker = $avail->moniker;
        return $avail if $host =~ m{$moniker};
    }

    # if none match then use the default
    return 'FixMyStreet::Cobrand::Default';
}

1;
