=head1 NAME

FixMyStreet::App::Form::Waste::Garden::Kingston::Subscribe - adding sacks to garden waste subscription form

=cut

package FixMyStreet::App::Form::Waste::Garden::Kingston::Subscribe;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Sacks';

=head2 intro_field_data

We want to ask about sacks if they have the flag set that means they have a domestic sack collection.

=cut

sub intro_field_data {
    my ($form, $data) = @_;
    my $c = $form->{c};
    $data->{_garden_sacks} = $c->stash->{slwp_garden_sacks};
}

=head2 include_bins_wanted

This is set to false, you can only request one sack subscription.

=cut

sub include_bins_wanted { 0 }

1;
