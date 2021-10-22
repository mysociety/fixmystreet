package FixMyStreet::Cobrand::Shropshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { return 2238; } # https://mapit.mysociety.org/area/2238.html
sub council_area { return 'Shropshire'; }
sub council_name { return 'Shropshire Council'; }
sub council_url { return 'shropshire'; }

sub admin_user_domain {
    'shropshire.gov.uk'
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.6354074681479,-2.73414274873688',
        span   => '0.692130766645555,1.00264228991404',
        bounds => [ 52.3062638566609, -3.23554076944319, 52.9983946233065, -2.23289847952914 ],
    };
}

1;
