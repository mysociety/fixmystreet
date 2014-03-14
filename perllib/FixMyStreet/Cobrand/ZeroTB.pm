package FixMyStreet::Cobrand::ZeroTB;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub site_title { return 'ZeroTB'; }

sub enter_postcode_text { return _ ('Enter a nearby street name and area, postal code or district in Delhi'); }

sub country {
    return 'IN';
}

sub languages { [ 'en-gb,English,en_GB' ] }
sub language_override { 'en-gb' }

sub disambiguate_location {
    return {
        country => 'in',
        town => 'Delhi',
        bounds => [ 28.404625000000024, 76.838845800000072, 28.884380600000028, 77.347877500000067 ],
    };
}

sub only_authed_can_create { return 1; }
sub allow_photo_display { return 0; }
sub allow_photo_upload{ return 0; }
sub send_questionnaires { return 0; }
sub on_map_default_max_pin_age { return 0; }

1;

