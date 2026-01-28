=head1 NAME

FixMyStreet::Cobrand::Dumfries - code specific to the Dumfries and Galloway cobrand

=head1 SYNOPSIS

Dumfries and Galloway is a unitary authority, with an Alloy backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Dumfries;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use Moo;
with 'FixMyStreet::Roles::MyGovScotOIDC';

use strict;
use warnings;

sub council_area_id { return 2656; }
sub council_area { return 'Dumfries and Galloway'; }
sub council_name { return 'Dumfries and Galloway Council'; }
sub council_url { return 'dumfries'; }

=item * Custom postcode text which includes hint about reference number search

=cut

sub enter_postcode_text {
    'Enter a Dumfries and Galloway post code or street name and area, or a reference number of a problem previously reported'
}

1;
