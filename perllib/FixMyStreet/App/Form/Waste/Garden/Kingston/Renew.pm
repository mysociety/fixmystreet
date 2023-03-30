package FixMyStreet::App::Form::Waste::Garden::Kingston::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Sacks::Renew';

=head2 include_bins_wanted

This is set to false, you can only request one sack subscription.

=cut

sub include_bins_wanted { 0 }

1;
