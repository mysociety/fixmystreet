package FixMyStreet::Cobrand::MiCalle;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub country {
    return 'DO';
}

sub languages { [ 'es-do,Spanish,es_DO' ] }
sub language_override { 'es-do' }

1;
