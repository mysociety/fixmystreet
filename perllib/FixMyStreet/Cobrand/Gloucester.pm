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

                # Hide Gloucestershire County's 'Dead animal' category
                'Dead animal at the side of the road',
            ],
            -not_like => 'Ash Tree located on%',
        },
    });
}

=item * TODO: Don't show reports before the go-live date

=cut

# sub cut_off_date { '2024-03-31' }

=back

=head2 pin_colour

* Yellow if open/confirmed

* Orange if in progress

* Green if fixed

* Grey if closed

=cut

sub pin_colour {
    my ( $self, $p ) = @_;
    return 'orange' if $p->is_in_progress;
    return 'green' if $p->is_fixed;
    return 'grey' if $p->is_closed;
    return 'yellow';
}

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
        result_strip => ', Gloucestershire, England',
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

=head2 _asset_layer_mapping

Gloucester's Alloy integration has assets separated into different layers.
When looking up a parent asset for a report that doesn't have one, we need
to know which layer(s) to check. This method provides a mapping from the
report category to the relevant asset layer(s). The asset layer names
correspond to asset layers configured in the Tilma proxy service.

=cut

sub _asset_layer_mapping {
    my $self = shift;
    my $layers = $self->feature("asset_layers") or return;
    my $out;
    foreach my $layer (@$layers) {
        next unless ref $layer eq 'HASH' && $layer->{http_options};
        if ($layer->{asset_category}) {
            my $cat = ref $layer->{asset_category} ? $layer->{asset_category} : [ $layer->{asset_category} ];
            foreach (@$cat) {
                push @{$out->{category}{$_}}, $layer->{http_options}{params}{layer};
            }
        }
        if ($layer->{asset_group}) {
            my $g = $layer->{asset_group};
            push @{$out->{group}{$g}}, $layer->{http_options}{params}{layer};
        }
    }
    return $out;
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
        if (my $item_id = $self->lookup_site_codes($row, $contact)) {
            $row->update_extra_field({ name => 'asset_resource_id', value => $item_id });
        }
    }
}

=head2 lookup_site_codes

The Alloy layer code uses lat/lon rather than easting/northing, and
can have multiple layers depending upon the report's category.

=cut

sub lookup_site_codes {
    my ($self, $row, $contact) = @_;

    my $mapping = $self->_asset_layer_mapping or return;
    my @groups = map { [ 'group', $_ ] } @{$contact->groups};
    my $category = [ 'category', $contact->category ];
    foreach (@groups, $category) {
        my ($type, $name) = @$_;
        my $layers = $mapping->{$type}{$name};
        next unless $layers && @$layers;
        for my $layer (@$layers) {
            my $item_id = $self->lookup_site_code($row, $layer);
            return $item_id if $item_id;
        }
    }
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;

    # Convert bbox from EN to lat/lon
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
