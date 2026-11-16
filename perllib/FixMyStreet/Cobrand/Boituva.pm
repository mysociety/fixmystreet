package FixMyStreet::Cobrand::Boituva;

use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;
use utf8;

sub country { 'BR' }

sub languages { ['pt-br,Português,pt_BR'] }
sub language_override { 'pt-br' }

sub enter_postcode_text {
    'Digite o endereço completo, número do protocolo ou ponto de referência';
}

sub lookup_by_ref_regex {
    return qr/^\s*(?:ref:\s*)?(\d+)\s*$/i;
}

1;
