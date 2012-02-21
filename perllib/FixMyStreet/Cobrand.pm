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

Return an array reference of allowed cobrand monikers and hostname substrings.

=cut

sub get_allowed_cobrands {
    my $class = shift;
    my @allowed_cobrands = map {
        ref $_ ? { moniker => keys %$_, host => values %$_ }
               : { moniker => $_, host => $_ }
    } @{ $class->_get_allowed_cobrands };
    return \@allowed_cobrands;
}

=head2 _get_allowed_cobrands

Simply returns the config variable (so this function can be overridden in test suite).

=cut

sub _get_allowed_cobrands {
    return FixMyStreet->config('ALLOWED_COBRANDS');
}

=head2 available_cobrand_classes

    @available_cobrand_classes =
      FixMyStreet::Cobrand->available_cobrand_classes();

Return an array of all the classes that were found and that have monikers
that match the values from get_allowed_cobrands, in the order of
get_allowed_cobrands.

=cut

sub available_cobrand_classes {
    my $class = shift;

    my %all = map { $_->moniker => $_ } @ALL_COBRAND_CLASSES;
    my @avail;
    foreach (@{ $class->get_allowed_cobrands }) {
        next unless $all{$_->{moniker}};
        $_->{class} = $all{$_->{moniker}};
        push @avail, $_;
    }

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
        return $avail->{class} if $host =~ /$avail->{host}/;
    }

    # if none match then use the default
    return 'FixMyStreet::Cobrand::Default';
}

=head2 get_class_for_moniker

    $cobrand_class = FixMyStreet::Cobrand->get_class_for_moniker( $moniker );

Given a moniker determine which cobrand we should be using. 

=cut

sub get_class_for_moniker {
    my $class   = shift;
    my $moniker = shift;

    foreach my $avail ( $class->available_cobrand_classes ) {
        return $avail->{class} if $moniker eq $avail->{moniker};
    }

    # Special case for old blank cobrand entries in fixmystreet.com.
    return 'FixMyStreet::Cobrand::FixMyStreet' if $moniker eq '';

    # if none match then use the default
    return 'FixMyStreet::Cobrand::Default';
}

1;
