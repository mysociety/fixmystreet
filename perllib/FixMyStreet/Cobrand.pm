# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: evdb@mysociety.org. WWW: http://www.mysociety.org

package FixMyStreet::Cobrand;

use strict;
use warnings;

use FixMyStreet;
use Carp;
use Package::Stash;

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
    my $allowed = FixMyStreet->config('ALLOWED_COBRANDS') || [];
    # If the user has supplied a string, convert to an arrayref
    $allowed = [ $allowed ] unless ref $allowed;
    return $allowed;
}

=head2 available_cobrand_classes

    @available_cobrand_classes =
      FixMyStreet::Cobrand->available_cobrand_classes();

Return an array of all the classes from get_allowed_cobrands, in
the order of get_allowed_cobrands, with added class information
for those that have found classes.

=cut

sub available_cobrand_classes {
    my $class = shift;

    my %all = map { $_->moniker => $_ } @ALL_COBRAND_CLASSES;
    my @avail;
    foreach (@{ $class->get_allowed_cobrands }) {
        #next unless $all{$_->{moniker}};
        $_->{class} = $all{$_->{moniker}};
        push @avail, $_;
    }

    return @avail;
}

=head2 class

=cut

sub class {
    my $avail = shift;
    return $avail->{class} if $avail->{class};
    my $moniker = "FixMyStreet::Cobrand::$avail->{moniker}";
    my $class = bless {}, $moniker;
    my $stash = Package::Stash->new($moniker);
    my $isa = $stash->get_or_add_symbol('@ISA');
    @{$isa} = ('FixMyStreet::Cobrand::Default');
    return $moniker;
}

=head2 get_class_for_host

    $cobrand_class = FixMyStreet::Cobrand->get_class_for_host( $host );

Given a host determine which cobrand we should be using. 

=cut

sub get_class_for_host {
    my $class = shift;
    my $host  = shift;

    my @available = $class->available_cobrand_classes;

    # If only one entry, always use it
    return class($available[0]) if 1 == @available;

    # If more than one entry, pick first whose regex (or
    # name by default) matches hostname
    foreach my $avail ( @available ) {
        return class($avail) if $host =~ /$avail->{host}/;
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
        return class($avail) if $moniker eq $avail->{moniker};
    }

    # Special case for old blank cobrand entries in fixmystreet.com.
    return 'FixMyStreet::Cobrand::FixMyStreet' if $moniker eq '';

    # if none match then use the default
    return 'FixMyStreet::Cobrand::Default';
}

=head2 exists

    FixMyStreet::Cobrand->exists( $moniker );

Given a moniker, returns true if that cobrand is available to us for use

=cut

sub exists {
    my ( $class, $moniker ) = @_;

    foreach my $avail ( $class->available_cobrand_classes ) {
        return 1 if $moniker eq $avail->{moniker};
    }

    return 0;
}

sub body_handler {
    my ($class, $areas) = @_;

    foreach my $avail ( $class->available_cobrand_classes ) {
        my $cobrand = $class->get_class_for_moniker($avail->{moniker})->new({});
        next unless $cobrand->can('council_area_id');
        return $cobrand if $areas->{$cobrand->council_area_id};
    }
}

1;
