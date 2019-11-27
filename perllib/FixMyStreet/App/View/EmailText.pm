package FixMyStreet::App::View::EmailText;
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
    disable_autoescape => 1,
);

=head1 NAME

FixMyStreet::App::View::EmailText - TT View for FixMyStreet::App

=head1 DESCRIPTION

A TT view for the text part of emails - so no HTML auto-escaping

=cut

1;

