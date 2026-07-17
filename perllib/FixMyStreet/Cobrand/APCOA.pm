=head1 NAME

FixMyStreet::Cobrand::APCOA - code specific to the APCOA cobrand

=head1 SYNOPSIS


=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::APCOA;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use utf8;
use strict;
use warnings;

sub council_area_id { return 145955; }
sub council_area { return 'Belfast'; }
sub council_name { return 'APCOA Parking'; }
sub council_url { return 'apcoa'; }

=item * Make a few improvements to the display of geocoder results

Remove 'County Borough of Belfast, Belfast City District, County Antrim/Down, Northern Ireland / Tuaisceart Éireann', skip any that don't mention Belfast at all

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Belfast',
        centre => '54.5963444441549,-5.94269398961836',
        span   => '0.134424745675503,0.2527715130238',
        bounds => [ 54.5305665063663, -6.06003004636155, 54.6649912520418, -5.80725853333775 ],
        result_only_if => 'Belfast',
        result_strip => 'County Borough of Belfast, Belfast City District, County (?:Antrim|Down), Northern Ireland / Tuaisceart Éireann, '
    };
}


1;
