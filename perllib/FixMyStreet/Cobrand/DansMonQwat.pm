package FixMyStreet::Cobrand::DansMonQwat;
use base 'FixMyStreet::Cobrand::Default';

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

1;
