package FixMyStreet::Cobrand::Rbkc;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2503 }
sub council_area { 'Kensington and Chelsea Borough Council' }
sub council_name { 'Kensington and Chelsea Borough Council' }
sub council_url { 'rbkc' }
sub admin_user_domain { 'rbkc.gov.uk' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.501206,-0.192219',
        bounds => [ 51.477221, -0.228727, 51.530352, -0.149843 ],
    };
}

1;
