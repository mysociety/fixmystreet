package FixMyStreet::Cobrand::Bromley;
use mro 'c3';
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

# Bromley pins always yellow
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'yellow';
}

sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    $num = 3 if $num > 3 && $area eq 'alert';
    return $self->problems->recent_photos( $num, $lat, $lon, $dist );
}

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

sub process_extras {
    my $self = shift;
    $self->SUPER::process_extras( @_, [ 'first_name', 'last_name' ] );
}

1;

