=head1 NAME

FixMyStreet::App::Form::Waste::Garden::Brent::Renew - staff-only garden waste renewal form (with sacks)

=cut

package FixMyStreet::App::Form::Waste::Garden::Brent::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Sacks::Renew';

=head2 include_bins_wanted

This is set to false, so that the sacks form does not ask for the number of sack subscriptions wanted.

=cut

sub include_bins_wanted { 0 }

1;
