package FixMyStreet::Cobrand::Myanmar;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub country {
    return 'MM';
}


sub languages { [ 'my-mm,Myanmar,my_MM', 'en-gb,English,en_GB' ] }

sub disambiguate_location {
    return {
        country => 'mm',
    };
}

1;

