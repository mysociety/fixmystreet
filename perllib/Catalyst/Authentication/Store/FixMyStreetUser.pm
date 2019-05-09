package Catalyst::Authentication::Store::FixMyStreetUser;

use Moose;
use namespace::autoclean;
extends 'Catalyst::Authentication::Store::DBIx::Class::User';

use Carp;
use Try::Tiny;

sub AUTOLOAD {
    my $self = shift;
    (my $method) = (our $AUTOLOAD =~ /([^:]+)$/);
    return if $method eq "DESTROY";

    if (my $code = $self->_user->can($method)) {
        return $self->_user->$code(@_);
    }
    elsif (my $accessor =
         try { $self->_user->result_source->column_info($method)->{accessor} }) {
        return $self->_user->$accessor(@_);
    } else {
        croak sprintf("Can't locate object method '%s'", $method);
    }
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
__END__

=head1 NAME

Catalyst::Authentication::Store::FixMyStreetUser - The backing user
class for the Catalyst::Authentication::Store::DBIx::Class storage
module, adjusted to die on unknown lookups.

=head1 DESCRIPTION

The Catalyst::Authentication::Store::FixMyStreetUser class implements user
storage connected to an underlying DBIx::Class schema object.

=head1 SUBROUTINES / METHODS

=head2 AUTOLOAD

Delegates method calls to the underlying user row.
Unlike the default, dies if an unknown method is called.

=head1 LICENSE

Copyright (c) 2007-2019. All rights reserved. This program is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
