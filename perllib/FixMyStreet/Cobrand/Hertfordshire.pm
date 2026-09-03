=head1 NAME

FixMyStreet::Cobrand::Whatever - code specific to the Whatever cobrand

=head1 SYNOPSIS

Hertfordshire is a unitary authority, with a Salesforce backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Hertfordshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2498; }
sub council_area { return 'Hertfordshire'; }
sub council_name { return 'Hertfordshire Council'; }
sub council_url { return 'hertfordshire'; }

1;
