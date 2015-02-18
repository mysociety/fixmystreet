package FixMyStreet::Cobrand::BellaVistaEnAccion;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub country {
    return 'CL';
}

sub example_places {
    return ( 'Dominica, Recoleta', 'Pio Nono' );
}

sub languages { [ 'es-cl,Castellano,es_CL' ] }

sub disambiguate_location {
    return {
        country => 'cl',
        town => 'Santiago',
    };
}

1;

