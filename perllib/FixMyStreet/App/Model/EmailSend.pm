package FixMyStreet::App::Model::EmailSend;
use base 'Catalyst::Model::Factory';

use strict;
use warnings;

=head1 NAME

FixMyStreet::App::Model::EmailSend

=head1 DESCRIPTION

Catalyst Model wrapper around FixMyStreet::EmailSend

=cut

__PACKAGE__->config(
    class => 'FixMyStreet::EmailSend',
);
