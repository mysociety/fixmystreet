package FixMyStreet::Cobrand::Northumberland;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { 2248 }
sub council_area { 'Northumberland' }
sub council_name { 'Northumberland County Council' }
sub council_url { 'northumberland' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        centre => '55.2426024934787,-2.06541585421059',
        span   => '1.02929721743568,1.22989513596542',
        bounds => [ 54.7823703267595, -2.68978494847825, 55.8116675441952, -1.45988981251283 ],
    };
}

1;
