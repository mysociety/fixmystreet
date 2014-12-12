package FixMyStreet::Cobrand::DansMonQwat;
use base 'FixMyStreet::Cobrand::Default';

use utf8;
use strict;
use warnings;

sub site_title { return 'DansMonQwat'; }

sub country {
    return 'CM';
}

sub enter_postcode_text {
    return 'You can text in your report to <strong>+237 56 72 65 11</strong>. Or:<br>'
        . _('Enter a nearby street name and area');
}

sub change_category_text {
    my ($self, $category) = @_;
    if ($category eq 'Poorly maintained roads') {
        return 'Routes dégradées';
    } elsif ($category eq 'Street lights') {
        return 'Éclairage public';
    } elsif ($category eq 'Dumped garbage') {
        return "Dépotoirs d'ordures sauvages";
    } elsif ($category eq 'Congested drains') {
        return 'Rigoles encombrés';
    } elsif ($category eq 'Broken fire hydrants') {
        return 'Borne fontaine en panne';
    }
    return $category;
}

1;
