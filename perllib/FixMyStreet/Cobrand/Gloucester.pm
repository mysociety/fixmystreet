=head1 NAME

FixMyStreet::Cobrand::Gloucester - code specific to the Gloucester cobrand

=head1 SYNOPSIS

We integrate with Gloucester's Alloy back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Gloucester;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::Open311Alloy';

=head2 Defaults

=over 4

=cut

sub council_area_id { '2325' }
sub council_area { 'Gloucester' }
sub council_name { 'Gloucester City Council' }
sub council_url { 'gloucester' }

=item * Users with a gloucester.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'gloucester.gov.uk' }

=item * Gloucester use their own privacy policy

=cut

sub privacy_policy_url {
    'https://www.gloucester.gov.uk/about-the-council/data-protection-and-freedom-of-information/data-protection/'
}

=item * Doesn't allow the reopening of reports

=cut

sub reopening_disallowed { 1 }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * Override the default text for entering a postcode or street name

=cut

sub enter_postcode_text {
    return 'Enter a Gloucester postcode or street name';
}

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

=item * It has a default map zoom of 3

=cut

sub default_map_zoom { 5 }

=item * Ignores some categories that are not relevant to Gloucester

=cut

sub categories_restriction {
    my ($self, $rs) = @_;

    return $rs->search({
        'me.category' => {
            -not_in => [
                # Hide all categories with parent 'Noxious weeds'
                'Giant Hogweed',
                'Himalayan Balsam',
                'Japanese Knotweed',
                'Nettles, brambles, dandelions etc.',
                'Ragwort',
            ],
            -not_like => 'Ash Tree located on%',
        },
    });
}

=item * TODO: Don't show reports before the go-live date

=cut

# sub cut_off_date { '2024-03-31' }

=pod

=back

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = 'Gloucester';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.8493825813624,-2.24025312382298',
        span   => '0.0776436939868574,0.12409536555503',
        bounds => [
            51.8075803711933, -2.30135343437398,
            51.8852240651802, -2.17725806881895
        ],
    };
}

# Include details of selected assets from their WFS service in the the alloy
# report description.
sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    if (my $wfs_asset_info = $row->get_extra_field_value('wfs_asset_info')) {
        my $text = "Asset Info: $wfs_asset_info\n\n" . $row->get_extra_field_value('description');
        $row->update_extra_field({ name => 'description', value => $text });
    }
}

# For categories where user has said they have witnessed activity, send
# an email
sub open311_post_send {
    my ( $self, $row, $h ) = @_;

    # Check Open311 was successful
    return unless $row->external_id;

    return if $row->get_extra_metadata('extra_email_sent');

    return if ( $row->get_extra_field_value('did_you_witness') || '' ) ne 'Yes';

    my $emails = $self->feature('open311_email') or return;
    my $dest = $emails->{$row->category} or return;

    my $sender = FixMyStreet::SendReport::Email->new( to => [$dest] );
    $sender->send( $row, $h );

    if ($sender->success) {
        $row->update_extra_metadata(extra_email_sent => 1);
    }
}

=head2 _asset_layer_mapping

Gloucester's Alloy integration has assets separated into different layers.
When looking up a parent asset for a report that doesn't have one, we need
to know which layer(s) to check. This method provides a mapping from the
report category to the relevant asset layer(s). The asset layer names
correspond to asset layers configured in the Tilma proxy service.

=cut

sub _asset_layer_mapping {
    return {
        'Broken_glass' => [ 'adopted_streets' ],
        'Damaged_dog_bin' => [ 'dog_bins' ],
        'Damaged_dual_use_bin' => [ 'all_street_bins' ],
        'Damaged_litter_bin' => [ 'all_street_bins' ],
        'Damaged_nameplate' => [ 'adopted_streets' ],
        'Damaged_or_dangerous_playground_equipment' => [ 'play_areas' ],
        'Damaged_park_furniture' => [ 'adopted_streets', 'all_sites' ],
        'Dangerous_nameplate' => [ 'adopted_streets' ],
        'Dead_animal_that_needs_removing' => [ 'all_streets', 'all_sites' ],
        'Debris_on_pavement_or_road' => [ 'adopted_streets' ],
        'Dog_fouling_(not_witnessed)' => [ 'adopted_streets' ],
        'Faded_nameplate_1' => [ 'adopted_streets' ],
        'Fly-posting' => [ 'adopted_streets', 'all_sites' ],
        'Items_in_watercourse' => [ 'adopted_streets', 'all_sites' ],
        'Leaves' => [ 'adopted_streets' ],
        'Litter_in_street_or_public_area' => [ 'adopted_streets' ],
        'Missing_bin' => [ 'all_street_bins' ],
        'Missing_nameplate' => [ 'adopted_streets' ],
        'Non-offensive_graffiti' => [ 'all_streets', 'all_sites' ],
        'Offensive_graffiti_(not_witnessed)' => [ 'all_streets', 'all_sites' ],
        'Overflowing_bin' => [ 'all_street_bins' ],
        'Overgrown_grass' => [ 'all_sites', 'all_plots' ],
        'Overgrown_hedges' => [ 'all_sites', 'all_plots' ],
        'Overgrown_weeds' => [ 'all_sites', 'all_plots' ],
        'Regular_fly-tipping_(not_witnessed_and_no_evidence_likely)' => [ 'adopted_streets', 'all_sites' ],
        'Spillage_after_recycling_collection' => [ 'all_streets' ],
        'Spillage_after_waste_collection' => [ 'all_streets' ],
        'Syringes_or_drugs_equipment' => [ 'all_streets', 'all_sites' ],
        'Unclean_public_toilets' => [ 'public_toilets' ],
    };
}

=head2 open311_update_missing_data

This is a hook called before sending a report to Open311. For the Gloucester
Alloy integration, all reports must be associated with a parent asset. If the
user hasn't selected one during reporting (e.g. on the app or with JavaScript
disabled), this method calls C<lookup_site_code> to find the nearest suitable
asset and attach it to the report.

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    # If the report doesn't already have an asset, associate it with the
    # closest feature from the Alloy asset layers.
    if (!$row->get_extra_field_value('asset_resource_id')) {
        if (my $item_id = $self->lookup_site_code($row, $contact)) {
            $row->update_extra_field({ name => 'asset_resource_id', value => $item_id });
        }
    }
}

=head2 lookup_site_code

This overrides the parent implementation to handle Gloucester's specific
multi-layer asset configuration in Alloy. Based on the report's category, it
determines which asset layer(s) to query using C<_asset_layer_mapping>. It
then iterates through the specified layers, searching for the nearest asset on
each one until a match is found.

=cut

sub lookup_site_code {
    my ($self, $row, $contact) = @_;

    my $category = $contact->category;
    my $layers = $self->_asset_layer_mapping->{$category};
    return unless $layers && @$layers;

    for my $layer (@$layers) {
        my $cfg = $self->lookup_site_code_config($layer);
        my ($x, $y) = $row->local_coords;
        my $features = $self->_fetch_features($cfg, $x, $y);
        if ($cfg->{_nearest_uses_latlon}) {
            ($x, $y) = ($row->longitude, $row->latitude);
        }
        if (my $item_id = $self->_nearest_feature($cfg, $x, $y, $features)) {
            return $item_id;
        }
    }
    return;
}

=head2 lookup_site_code_config

This method generates the configuration required by C<lookup_site_code> to
query a specific asset layer in Gloucester's Alloy system. Unlike other cobrands
that might have a single, static configuration, this one is parameterised by
the asset C<$layer> to allow for checking multiple different layers for a single report.

=cut

sub lookup_site_code_config {
    my ($self, $layer) = @_;

    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    return {
        buffer => 200, # metres
        _nearest_uses_latlon => 1,
        proxy_url => "https://$host/alloy/layer.php",
        layer => $layer,
        url => "https://gloucester.assets",
        property => "itemId",
        accept_feature => sub { 1 },
    };
}

1;
