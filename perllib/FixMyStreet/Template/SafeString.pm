package FixMyStreet::Template::SafeString;

use strict;
use warnings;

=head1 NAME

FixMyStreet::Template::SafeString - a string that won't be escaped on output in a template

=cut

use overload
    '""' => sub { ${$_[0]} },
    '.'  => \&concat,
    '.=' => \&concatequals,
    '='  => \&clone,
    'cmp' => \&cmp,
;

sub new {
    my ($class, $value) = @_;

    my $self = bless \$value, $class;

    return $self;
}

sub cmp {
    my ($self, $str) = @_;

    if (ref $str eq __PACKAGE__) {
        return $$self cmp $$str;
    } else {
        return $$self cmp $str;
    }
}

sub concat {
    my ($self, $str, $prefix) = @_;

    return $self->clone() if not defined $str or $str eq '';

    if ( $prefix ) {
        return $str . $$self;
    } else {
        return $$self . $str;
    }
}

sub concatequals {
    my ($self, $str, $prefix) = @_;

    if ( ref $str eq __PACKAGE__) {
        $$self .= $$str;
        return $self;
    } else {
        return $self->clone() if $str eq '';
        $$self .= $str;
        return $$self;
    }
}

sub clone {
    my $self = shift;

    my $val = $$self;
    my $clone = bless \$val, ref $self;

    return $clone;
}

sub TO_JSON {
    my $self = shift;

    return $$self;
}

1;
__END__

=head1 SYNOPSIS

  use FixMyStreet::Template;
  use FixMyStreet::Template::SafeString;

  my $s1 = "< test & stuff >";
  my $s2 = FixMyStreet::Template::SafeString->new($s1);

  my $tt = FixMyStreet::Template->new();
  $tt->process(\"[% s1 %] * [% s2 %]\n", { s1 => $s1, s2 => $s2 });

  # Produces output "&lt; test &amp; stuff &gt; * < test & stuff >"

=head1 DESCRIPTION

This object provides a safe string to use as part of the FixMyStreet::Template
extension. It will not be automatically escaped when used, so can be used to
pass HTML to a template by a function that is safely creating some.

=head1 AUTHOR

Matthew Somerville, E<lt>matthew@mysociety.orgE<gt>

Martyn Smith, E<lt>msmith@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
