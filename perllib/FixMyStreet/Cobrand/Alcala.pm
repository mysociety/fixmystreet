package FixMyStreet::Cobrand::Alcala;
use base 'FixMyStreet::Cobrand::Default';

use utf8;
use strict;
use warnings;

sub is_council {
    1;
}

sub language_override { 'es' }

#mapit id for Alcalá
sub council_id { return 579300; }
 
sub council_area { return 'Alcalá de Henares'; }
sub council_name { return 'Ayto. de Alcalá de Henares'; }
#sub council_url { return 'bromley'; }

1;
