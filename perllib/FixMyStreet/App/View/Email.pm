package FixMyStreet::App::View::Email;
use base 'Catalyst::View::TT';

use strict;
use warnings;

use FixMyStreet;
use FixMyStreet::Template;

__PACKAGE__->config(
    CLASS => 'FixMyStreet::Template',
    TEMPLATE_EXTENSION => '.txt',
    INCLUDE_PATH => [ FixMyStreet->path_to( 'templates', 'email', 'default' ) ],
    render_die => 1,
);

=head1 NAME

FixMyStreet::App::View::Email - TT View for FixMyStreet::App

=head1 DESCRIPTION

TT View for FixMyStreet::App.

=cut

1;

