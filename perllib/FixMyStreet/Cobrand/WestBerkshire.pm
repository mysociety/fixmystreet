package FixMyStreet::Cobrand::WestBerkshire;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub council_area_id { 2619 }

# non standard west berks end points
sub open311_pre_send {
    my ($self, $row, $open311) = @_;
    $open311->endpoints( { services => 'Services', requests => 'Requests' } );
}

1;

