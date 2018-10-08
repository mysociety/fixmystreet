package FixMyStreet::Cobrand::Lewisham;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub council_area_id { 2492 }

sub open311_post_update_skip {
    my ($self) = @_;
    return 1;
}

1;

