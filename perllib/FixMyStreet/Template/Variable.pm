package FixMyStreet::Template::Variable;

use strict;
use warnings;
use FixMyStreet::Template;

sub op_factory {
    my ($op) = @_;

    return eval q|sub {
        my ($self, $str, $swapped) = @_;

        if ( ref $str eq __PACKAGE__) {
            return $self->{value} | . $op . q| $str->{value} unless $swapped;
            return $str->{value} | . $op . q| $self->{value};
        }
        else {
            return $self->{value} | . $op . q| $str unless $swapped;
            return $str | . $op . q| $self->{value};
        }
    }|;
}

use overload
    '""'   => \&html_encoded,
    '.'    => \&concat,
    '.='   => \&concatequals,
    '='    => \&clone,

    'cmp' => op_factory('cmp'),
    'eq'  => op_factory('eq'),
    '<=>' => op_factory('<=>'),
    '=='  => op_factory('=='),
    '%'   => op_factory('%'),
    '+'   => op_factory('+'),
    '-'   => op_factory('-'),
    '*'   => op_factory('*'),
    '/'   => op_factory('/'),
    '**'  => op_factory('**'),
    '>>'  => op_factory('>>'),
    '<<'  => op_factory('<<'),
;

sub new {
    my ($class, $value) = @_;

    my $self = bless { value => $value }, $class;

    return $self;
}

sub plain {
    my $self = shift;

    return $self->{value};
}

sub html_encoded {
    my $self = shift;
    return FixMyStreet::Template::html_filter($self->{value});
}

sub concat {
    my ($self, $str, $prefix) = @_;

    # Special case where we're _not_ going to html_encode now now
    return $self->clone() if not defined $str or $str eq '';

    if ( $prefix ) {
        return $str . $self->html_encoded();
    }
    else {
        return $self->html_encoded() . $str;
    }
}

sub concatequals {
    my ($self, $str, $prefix) = @_;

    if ( ref $str eq __PACKAGE__) {
        $self->{value} .= $str->{value};
        return $self;
    }
    else {
        # Special case where we're _not_ going to html_encode now now
        return $self->clone() if $str eq '';

        # Fix Template::HTML::Variable issue with double output
        my $ret = $self->html_encoded . $str;
        $self->{value} .= $str;
        return $ret;
    }
}

sub clone {
    my $self = shift;

    my $clone = bless { %$self }, ref $self;

    return $clone;
}

1;
__END__

=head1 NAME

FixMyStreet::Template::Variable - A "pretend" string that auto HTML encodes;
a copy of Template::HTML::Variable with a bugfix.

=head1 SYNOPSIS

  use FixMyStreet::Template::Variable;

  my $string = FixMyStreet::Template::Variable->new('< test & stuff >');

  print $string, "\n";

  # Produces output "&lt; test &amp; stuff &gt;"

=head1 DESCRIPTION

This object provides a "pretend" string to use as part of the
FixMyStreet::Template extension.

It automatically stringifies to an HTML encoded version of what it was created
with, all the while trying to keep a sane state through string concatinations
etc.

=head1 FUNCTIONS

=head2 new()

Takes a single argument which is the string to set this variable to

=head2 plain()

Returns a non HTML-encoded version of the string (i.e. exactly what was passed
to the new() function

=head2 html_encoded()

Returns an HTML encoded version of the string (used by the stringify
overloads)

=head2 concat()

Implementation of overloaded . operator

=head2 concatequals()

Implementation of overloaded .= operator.

The original Template::HTML::Variable has a bug here, whereby it adds the new
string to its internal value, then returns the HTML encoded version of the
whole string with the new string concatenated again (unescaped).

=head2 clone()

Returns a clone of this variable. (used for the implementation of the
overloaded = operator).

=head2 op_factory()

Factory for generating operator overloading subs

=head1 AUTHOR

Martyn Smith, E<lt>msmith@cpan.orgE<gt>

Matthew Somerville, E<lt>matthew@mysociety.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
