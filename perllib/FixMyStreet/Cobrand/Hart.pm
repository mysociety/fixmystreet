=head1 NAME

FixMyStreet::Cobrand::Hart - code specific to the Hart cobrand

=head1 SYNOPSIS

Hart is a district council, within the county of Hampshire.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Hart;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2333; } # http://mapit.mysociety.org/area/2333.html
sub council_area { return 'Hart'; }
sub council_name { return 'Hart District Council'; }
sub council_url { return 'hart'; }
sub is_two_tier { return 1; }

=over 4

=item * We try and restrict reports to the area covered by Hart.

=cut

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
        result_strip => ', Hart, Hampshire, England',
    };
}

=item * Hart do not want the 'Graffiti on bridges/subways' category showing on their cobrand.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { category => { '!=' => 'Graffiti on bridges/subways' } } );
}

=item * We do not send questionnaires, or ask if someone has ever reported before.

=cut

sub send_questionnaires { 0 }

sub ask_ever_reported {
    return 0;
}

=item * The default map zoom is always 3.

=cut

sub default_map_zoom { 3 }

=item * We only show 20 reports per page.

=cut

sub reports_per_page { return 20; }

=item * Use own privacy policy link

=cut

sub privacy_policy_url { 'https://www.hart.gov.uk/privacy/corporate-services-privacy' }

=item * We have aerial maps

=cut

sub has_aerial_maps { 'tilma.mysociety.org/mapcache/gmaps/hartaerial@{grid}' }

=item * Green ticks for fixed reports

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $context ne 'reports' && !$self->owns_problem($p);
    return 'green-tick' if $p->is_fixed;
    return $self->next::method($p, $context);
}

1;

