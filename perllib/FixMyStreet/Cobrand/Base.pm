package FixMyStreet::Cobrand::Base;

use strict;
use warnings;

=head2 new

    my $cobrand = $class->new;
    my $cobrand = $class->new( { c => $c } );

Create a new cobrand object, optionally setting the context.

You probably shouldn't need to do this and should get the cobrand object via a
method in L<FixMyStreet::Cobrand> instead.

=cut

sub new {
    my $class = shift;
    my $self = shift || {};
    return bless $self, $class;
}

=head2 moniker

    $moniker = $cobrand_class->moniker();

Returns a moniker that can be used to identify this cobrand. By default this is
the last part of the class name lowercased - eg 'F::C::SomeCobrand' becomes
'somecobrand'.

=cut

sub moniker {
    my $class = ref( $_[0] ) || $_[0];    # deal with object or class
    my ($last_part) = $class =~ m{::(\w+)$};
    $last_part = lc($last_part);
    return $last_part;
}

=head2 is_default

    $bool = $cobrand->is_default();

Returns true if this is the default cobrand, false otherwise.

=cut

sub is_default {
    my $self = shift;
    return $self->moniker eq 'default';
}

# NB: this Base class is for 'meta' features.  To add base methods for all cobrands,
# you may want to look at FMS::Cobrand::Default instead!

1;

