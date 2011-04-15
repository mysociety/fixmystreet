package FixMyStreet::FakeQ;

use strict;
use warnings;
use Carp;

=head1 NAME

FixMyStreet::FakeQ - adaptor object to ease code transition

=head1 DESCRIPTION

The old code uses '$q' everywhere - partly to passaround which cobrand is in
use, partly to give access to the request query parameters and partly as a
scratch pad.

This object lets us fake this behaviour in a structured way so that the new
Catalyst based code can call the old CGI code with no need for changes.

Eventually it will be phased out.

=head1 METHODS

=head2 new

    $fake_q = FixMyStreet::FakeQ->new( $args );

Create a new FakeQ object. Checks that 'site' argument is present and corrects
it if needed.

=cut

sub new {
    my $class = shift;
    my $args = shift || {};

    croak "required argument 'site' missing" unless $args->{site};
    $args->{site} = 'fixmystreet' if $args->{site} eq 'default';

    $args->{params} ||= {};

    return bless $args, $class;
}

=head2 param

    $val = $fake_q->param( 'key' );

Behaves much like CGI's ->param. Returns value if found, or undef if not.

=cut

sub param {
    my $self = shift;
    my $key  = shift;

    return $self->{params}->{$key};
}

1;
