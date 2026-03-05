=head1 NAME

FixMyStreet::Cobrand::Whatever - code specific to the Whatever cobrand

=head1 SYNOPSIS

Rutland is a unitary authority, with a Salesforce backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::CanalRiverTrust;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2498; }
sub council_area { return 'CanalRiverTrust'; }
sub council_name { return 'Canal River Trust'; }
sub council_url { return 'canalrivertrust'; }

1;
