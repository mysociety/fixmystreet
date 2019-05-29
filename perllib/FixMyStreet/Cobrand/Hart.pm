package FixMyStreet::Cobrand::Hart;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2333; } # http://mapit.mysociety.org/area/2333.html
sub council_area { return 'Hart'; }
sub council_name { return 'Hart Council'; }
sub council_url { return 'hart'; }
sub is_two_tier { return 1; }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Hart, Hampshire';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        # these are taken from mapit http://mapit.mysociety.org/area/2333/geometry -- should be automated?
        centre => '51.284839,-0.8974600',
        span   => '0.180311,0.239375',
        bounds => [ 51.186005, -1.002295, 51.366316, -0.762920 ],
    };
}

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { category => { '!=' => 'Graffiti on bridges/subways' } } );
}

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

sub default_map_zoom { 3 }

sub reports_per_page { return 20; }

1;

