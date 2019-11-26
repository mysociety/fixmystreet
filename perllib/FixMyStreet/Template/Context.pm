package FixMyStreet::Template::Context;

use strict;
use warnings;
use base qw(Template::Context);

sub filter {
    my $self = shift;
    my ($name, $args, $alias) = @_;

    # If we're passing through the safe filter, then unwrap
    # from a Template::HTML::Variable if we are one.
    if ( $name eq 'safe' ) {
        return sub {
            my $value = shift;
            return $value->plain if UNIVERSAL::isa($value, 'FixMyStreet::Template::Variable');
            return $value;
        };
    }

    my $filter = $self->SUPER::filter(@_);

    # If we are already going to auto-encode, we don't want to do it again.
    # This makes the html filter a no-op on auto-encoded variables.
    if ( $name eq 'html' ) {
        return sub {
            my $value = shift;
            return $value if UNIVERSAL::isa($value, 'FixMyStreet::Template::Variable');
            return $filter->($value);
        };
    }

    return sub {
        my $value = shift;

        if ( UNIVERSAL::isa($value, 'FixMyStreet::Template::Variable') ) {
            my $result = $filter->($value->plain);
            return $result if UNIVERSAL::isa($result, 'FixMyStreet::Template::SafeString');
            return ref($value)->new($result);
        }

        return $filter->($value);
    };
}

1;
__END__

=head1 NAME

FixMyStreet::Template::Context - Similar to Template::HTML::Context but use
'safe' rather than 'none' to be clear, also prevents html filter double-encoding,
and doesn't rewrap a FixMyStreet::Template::SafeString.

=head1 AUTHORS

Martyn Smith, E<lt>msmith@cpan.orgE<gt>

Matthew Somerville, E<lt>matthew@mysociety.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
