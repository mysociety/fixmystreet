use utf8;
package FixMyStreet::Cobrand::HighwaysEngland;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub enter_postcode_text { 'Enter a location, road name or postcode' }

sub example_places {
    ['M60, Junction 2’, ‘M6 323.5', 'Spaghetti Junction']
}

sub allow_photo_upload { 0 }

1;
