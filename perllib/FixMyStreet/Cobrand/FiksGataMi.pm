package FixMyStreet::Cobrand::FiksGataMi;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use Carp;

sub set_lang_and_domain {
    my ( $self, $lang, $unicode, $dir ) = @_;
    mySociety::Locale::negotiate_language(
        'en-gb,English,en_GB|nb,Norwegian,nb_NO', 'nb' );
    mySociety::Locale::gettext_domain( 'FixMyStreet', $unicode, $dir );
    mySociety::Locale::change();
}

sub enter_postcode_text {
    my ( $self, $q ) = @_;
    return _('Enter a nearby postcode, or street name and area:');
}

# Is also adding language parameter
sub disambiguate_location {
    my ( $self, $s, $q ) = @_;
    $s = "hl=no&gl=no&$s";
    return $s;
}

sub area_types {
    return ( 'NKO', 'NFY' );
}

sub area_min_generation {
    return '';
}

1;

