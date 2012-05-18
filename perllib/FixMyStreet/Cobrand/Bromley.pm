package FixMyStreet::Cobrand::Bromley;
use parent 'FixMyStreet::Cobrand::FixMyStreet';
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2482; }
sub council_area { return 'Bromley'; }
sub council_name { return 'Bromley Council'; }
sub council_url { return 'bromley'; }

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub site_title {
    my ($self) = @_;
    return "London Borough of Bromley - Report a problem in Bromley\x{2019}s streets or parks";
}

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town => 'Bromley',
        centre => '51.366836,0.040623',
        span   => '0.154963,0.24347',
        bounds => [ '51.289355,-0.081112', '51.444318,0.162358' ],
    };
}

sub example_places {
    return ( 'BR1 3UH', 'Glebe Rd, Bromley' );
}

sub on_map_default_max_pin_age {
    return '1 month';
}

sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    $num = 3 if $num > 3 && $area eq 'alert';
    return $self->problems->recent_photos( $num, $lat, $lon, $dist );
}

sub pin_colour {
    my ( $self, $p ) = @_;
    #return 'green' if time() - $p->confirmed_local->epoch < 7 * 24 * 60 * 60;
    return 'yellow';
}

1;

