package FixMyStreet::Cobrand::Warwickshire;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2243; }
sub council_area { return 'Warwickshire'; }
sub council_name { return 'Warwickshire County Council'; }
sub council_url { return 'warwickshire'; }

sub is_two_tier { return 1; }

# Different to councils parent due to this being a two-tier council. If we get
# more, this can be genericised in the parent.
sub problems_clause {
    return { bodies_str => { like => '%2243%' } };
}


sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Warwick',
        centre => '52.300638,-1.559546',
        span   => '0.73185,0.789867',
        bounds => [ 51.955394, -1.962007, 52.687244, -1.172140 ],
    };
}

sub example_places {
    return [ 'CV34 3BU', 'Stratford Rd' ];
}

1;
