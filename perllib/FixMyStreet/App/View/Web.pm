package FixMyStreet::App::View::Web;
use base 'Catalyst::View::TT';

use strict;
use warnings;

use mySociety::Locale;
use FixMyStreet;

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.html',
    INCLUDE_PATH       => [          #
        FixMyStreet->path_to( 'templates', 'web', 'default' ),
    ],
    ENCODING       => 'utf8',
    render_die     => 1,
    expose_methods => [ 'loc', 'nget', 'tprintf', ],
);

=head1 NAME

FixMyStreet::App::View::Web - TT View for FixMyStreet::App

=head1 DESCRIPTION

TT View for FixMyStreet::App.

=cut

=head2 loc

    [% loc('Some text to localize') %]

Passes the text to the localisation engine for translations.

=cut

sub loc {
    my ( $self, $c, @args ) = @_;
    return _(@args);
}

=head2 nget

    [% nget( 'singular', 'plural', $number ) %]

Use first or second srting depending on the number.

=cut

sub nget {
    my ( $self, $c, @args ) = @_;
    return mySociety::Locale::nget(@args);
}

=head2 tprintf

    [% tprintf( 'foo %s bar', 'insert' ) %]

sprintf (different name to avoid clash)

=cut

sub tprintf {
    my ( $self, $c, $format, @args ) = @_;
    return sprintf $format, @args;
}

1;

