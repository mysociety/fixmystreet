=head1 NAME

FixMyStreet::Cobrand::Dumfries - code specific to the Dumfries and Galloway cobrand

=head1 SYNOPSIS

Dumfries and Galloway is a unitary authority, with an Alloy backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Dumfries;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2656; }
sub council_area { return 'Dumfries and Galloway'; }
sub council_name { return 'Dumfries and Galloway'; }
sub council_url { return 'dumfriesandgalloway'; }

=item * Dumfries use their own privacy policy

=cut

sub privacy_policy_url { 'https://www.dumfriesandgalloway.gov.uk/sites/default/files/2025-03/privacy-notice-customer-services-centres-dumfries-and-galloway-council.pdf' }


1;
