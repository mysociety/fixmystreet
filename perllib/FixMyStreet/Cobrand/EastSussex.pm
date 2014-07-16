package FixMyStreet::Cobrand::EastSussex;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2224; }
sub council_area { return 'East Sussex'; }
sub council_name { return 'East Sussex County Council'; }
sub council_url { return 'eastsussex'; }
# sub is_two_tier { return 1; }

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'East Sussex',
        centre => '50.9413275309703,0.276320277101682',
        span   => '0.414030932264716,1.00374244745585',
        bounds => [ 50.7333642759327, -0.135851370247794, 51.1473952081975, 0.867891077208056 ],
    };
}

sub example_places {
    return ( 'BN7 2LZ', 'White Hill, Lewes' );
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an East Sussex postcode, or street name and area';
}

# increase map zoom level so street names are visible
sub default_map_zoom { return 3; }

1;

