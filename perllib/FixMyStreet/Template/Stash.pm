package FixMyStreet::Template::Stash;

use strict;
use warnings;
use base qw(Template::Stash);
use FixMyStreet::Template::Variable;
use Scalar::Util qw(blessed);

sub get {
    my $self = shift;

    my $value = $self->SUPER::get(@_);

    $value = FixMyStreet::Template::Variable->new($value) unless ref $value;

    return $value;
}

# To deal with being able to call var.upper or var.match
sub _dotop {
    my $self = shift;
    my ($root, $item, $args, $lvalue) = @_;

    $args ||= [ ];
    $lvalue ||= 0;

    return undef unless defined($root) and defined($item);
    return undef if $item =~ /^[_.]/;

    if (blessed($root) && $root->isa('FixMyStreet::Template::Variable')) {
        if ((my $value = $Template::Stash::SCALAR_OPS->{ $item }) && ! $lvalue) {
            my @result = &$value($root->{value}, @$args);
            if (defined $result[0]) {
                return scalar @result > 1 ? [ @result ] : $result[0];
            }
            return undef;
        }
    }

    return $self->SUPER::_dotop(@_);
}

1;
__END__

=head1 NAME

FixMyStreet::Template::Stash - The same as Template::HTML::Stash, but
additionally copes with scalar operations on stash items.

=head1 FUNCTIONS

=head2 get()

An overridden function from Template::Stash that calls the parent class's get
method, and returns a FixMyStreet::Template::Variable instead of a raw string.

=head2 _dotop()

An overridden function from Template::Stash so that scalar operations on
wrapped FixMyStreet::Template::Variable strings still function correctly.

=head1 AUTHOR

Martyn Smith, E<lt>msmith@cpan.orgE<gt>

Matthew Somerville, E<lt>matthew@mysociety.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
