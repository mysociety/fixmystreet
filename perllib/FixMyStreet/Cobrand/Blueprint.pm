=head1 NAME

FixMyStreet::Cobrand::Whatever - code specific to the Whatever cobrand

=head1 SYNOPSIS

Rutland is a unitary authority, with a Salesforce backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Blueprint;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2498; }
sub council_area { return 'Blueprint'; }
sub council_name { return 'Blueprint Council'; }
sub council_url { return 'blueprint'; }

1;
