=head1 NAME

FixMyStreet::App::Form::Waste::Garden::Brent::Subscribe - staff-only garden waste subscription form (with sacks)

=cut

package FixMyStreet::App::Form::Waste::Garden::Brent::Subscribe;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Sacks';

=head2 intro_field_data

We always want to ask about sacks (this form is only used if the user is staff).

=cut

sub intro_field_data {
    my ($form, $data) = @_;
    $data->{_garden_sacks} = 1;
}

=head2 include_bins_wanted

This is set to false, so that the sacks form does not ask for the number of sack subscriptions wanted.

=cut

sub include_bins_wanted { 0 }

1;
