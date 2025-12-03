=head1 NAME

FixMyStreet::Cobrand::Dumfries - code specific to the Dumfries and Galloway cobrand

=head1 SYNOPSIS

Dumfries and Galloway Council (DGC) is a unitary authority, with an Alloy backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Dumfries;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use Moo;
with 'FixMyStreet::Roles::Open311Alloy';

use strict;
use warnings;

sub council_area_id { return 2656; }
sub council_area { return 'Dumfries and Galloway'; }
sub council_name { return 'Dumfries and Galloway'; }
sub council_url { return 'dumfries'; }

=item * Dumfries use their own privacy policy

=cut

sub privacy_policy_url { 'https://www.dumfriesandgalloway.gov.uk/sites/default/files/2025-03/privacy-notice-customer-services-centres-dumfries-and-galloway-council.pdf' }


=item * Make a few improvements to the display of geocoder results

Remove 'Dumfries and Galloway' and 'Alba / Scotland', skip any that don't mention Dumfries and Galloway at all

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = 'Dumfries and Galloway';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '55.0706745777256,-3.95683358209527',
        span   => '0.830832259321063,2.33028835283733',
        bounds => [ 54.6332195775134, -5.18762505731414, 55.4640518368344, -2.8573367044768 ],
        result_only_if => 'Dumfries and Galloway',
        result_strip => ', Dumfries and Galloway, Alba / Scotland',
    };
}

=head2 open311_update_missing_data

All reports sent to Alloy should have a parent asset they're associated with.
This is indicated by the value in the asset_resource_id field. For certain
categories (e.g. street lights) this will be the asset the user
selected from the map. For other categories (e.g. potholes) or if the user
didn't select an asset then we look up the nearest road from DGC's
Alloy server and use that as the parent.

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    if (!$row->get_extra_field_value('asset_resource_id')) {
        if (my $item_id = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'asset_resource_id', value => $item_id });
        }
    }
}


sub lookup_site_code_config {
    my ($self) = @_;
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";

    my $suffix = FixMyStreet->config('STAGING_SITE') ? "staging" : "assets";
    return {
        buffer => 200, # metres
        _nearest_uses_latlon => 1,
        proxy_url => "https://$host/alloy/layer.php",
        layer => "designs_highwaysNetworkAsset_64bf8f949c5fa17f953be9d6",
        url => "https://dumfries.$suffix",
        property => "itemId",
        accept_feature => sub { 1 }
    };
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;

    # Alloy layer proxy needs the bbox in lat/lons
    my ($w, $s, $e, $n) = split(/,/, $cfg->{bbox});
    ($s, $w) = Utils::convert_en_to_latlon($w, $s);
    ($n, $e) = Utils::convert_en_to_latlon($e, $n);
    my $bbox = "$w,$s,$e,$n";

    my $uri = URI->new($cfg->{proxy_url});
    $uri->query_form(
        layer => $cfg->{layer},
        url => $cfg->{url},
        bbox => $bbox,
    );

    return $uri;
}


1;
