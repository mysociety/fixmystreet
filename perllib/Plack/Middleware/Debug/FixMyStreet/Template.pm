package Plack::Middleware::Debug::FixMyStreet::Template;

=head1 NAME

Plack::Middleware::Debug::FixMyStreet::Template -
small subclass for FixMyStreet-specific tweaks.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

use strict;
use warnings;
use parent qw(Plack::Middleware::Debug::Template);

sub show_pathname { 1 }

sub hook_pathname {
    my ($self, $name) = @_;
    $name =~ s/^.*templates\/web\///;
    $name;
}

sub ignore_template {
    my ($self, $template) = @_;
    return 1 if $template eq 'site-name.html';
}

1;
