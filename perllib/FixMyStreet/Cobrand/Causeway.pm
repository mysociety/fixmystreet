=head1 NAME

FixMyStreet::Cobrand::Whatever - code specific to the Whatever cobrand

=head1 SYNOPSIS

Rutland is a unitary authority, with a Salesforce backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Causeway;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2498; }
sub council_area { return 'Causeway'; }
sub council_name { return 'Causeway'; }
sub council_url { return 'Causeway'; }

1;
