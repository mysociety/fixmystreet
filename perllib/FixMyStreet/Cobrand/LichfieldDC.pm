package FixMyStreet::Cobrand::LichfieldDC;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2434; }
sub council_area { return 'Lichfield district'; }
sub council_name { return 'Lichfield District Council'; }
sub council_url { return 'lichfielddc'; }

# Different to councils parent due to this being a two-tier council. If we get
# more, this can be genericised in the parent.
sub problems_clause {
    return { council => { like => '%2434%' } };
}

# FIXME - need to double check this is all correct
sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.688198,-1.804966',
        span   => '0.1196,0.218675',
        bounds => [ '52.584891,-1.963232', '52.807793,-1.586291' ],
    };
}

# If we ever link to a county problem report, needs to be to main FixMyStreet
sub url_for_report {
    my ( $self, $problem ) = @_;
    my %councils = map { $_ => 1 } @{$problem->councils};
    if ( $councils{2434} ) {
        return $self->base_url . $problem->url;
    } else {
        return FixMyStreet->config('BASE_URL') . $problem->url;
    }
}

1;

