package FixMyStreet::Cobrand::LichfieldDC;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2434; }
sub council_area { return 'Lichfield district'; }
sub council_name { return 'Lichfield District Council'; }
sub council_url { return 'lichfielddc'; }
sub is_two_tier { return 1; }

# Different to councils parent due to this being a two-tier council. If we get
# more, this can be genericised in the parent.
sub problems_clause {
    return { bodies_str => { like => '%2434%' } };
}

# FIXME - need to double check this is all correct
sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.688198,-1.804966',
        span   => '0.1196,0.218675',
        bounds => [ 52.584891, -1.963232, 52.807793, -1.586291 ],
    };
}

sub map_type {
    return 'OSM';
}

1;

