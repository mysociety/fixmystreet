=head1 NAME

FixMyStreet::Cobrand::Bristol - code specific to the Bristol cobrand

=head1 SYNOPSIS

Bristol is a unitary authority, with its own Open311 server.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Bristol;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

=head2 Defaults

=over 4

=cut

sub council_area_id {
    [
        2561,  # Bristol City Council
        2642,  # North Somerset Council
        2608,  # South Gloucestershire Council
    ]
}
sub council_area { return 'Bristol'; }
sub council_name { return 'Bristol City Council'; }
sub council_url { return 'bristol'; }

=item * Bristol use the OS Maps API at all zoom levels.

=cut

sub map_type { 'OS::API' }

=item * Users with a bristol.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'bristol.gov.uk' }

=item * Bristol uses the OSM geocoder

=cut

sub get_geocoder { 'OSM' }

=item * We do not send questionnaires.

=back

=cut

sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bristol';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.4526044866206,-2.7706173308649',
        span   => '0.202810508012753,0.60740886659825',
        bounds => [ 51.3415749466466, -3.11785543094126, 51.5443854546593, -2.51044656434301 ],
    };
}

=head2 pin_colour

Bristol uses the following pin colours:

=over 4

=item * grey: closed as 'not responsible'

=item * green: fixed or otherwise closed

=item * red: newly open

=item * yellow: any other open state

=back

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

use constant ROADWORKS_CATEGORY => 'Inactive roadworks';

=head2 categories_restriction

Categories covering the Bristol area have a mixture of Open311 and Email send
methods. Bristol only want Open311 categories to be visible on their cobrand,
not the email categories from FMS.com. We've set up the Email categories with a
devolved send_method, so can identify Open311 categories as those which have a
blank send_method. Also National Highways categories have a blank send_method.
Additionally the special roadworks category should be shown.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { -or => [
        'me.category' => ROADWORKS_CATEGORY, # Special new category
        'me.send_method' => undef, # Open311 categories
        'me.send_method' => '', # Open311 categories that have been edited in the admin
    ] } );
}

=head2 open311_config

Bristol's endpoint requires an email address, so flag to always send one (with
a fallback if one not provided).

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{always_send_email} = 1;
    $params->{multi_photos} = 1;
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{multi_photos} = 1;
}

=head2 open311_contact_meta_override

We need to mark some of the attributes returned by Bristol's Open311 server
as hidden or server_set.

=cut

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    my %server_set = (easting => 1, northing => 1);
    my %hidden_field = (usrn => 1, asset_id => 1);
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
        $_->{automated} = 'hidden_field' if $hidden_field{$_->{code}};
    }
}

=head2 post_report_sent

Bristol have a special Inactive roadworks category; any reports made in that
category are automatically closed, with an update with explanatory text added.

=cut

sub post_report_sent {
    my ($self, $problem) = @_;

    if ($problem->category eq ROADWORKS_CATEGORY) {
        $self->_post_report_sent_close($problem, 'report/new/roadworks_text.html');
    }
}

=head2 munge_overlapping_asset_bodies

Bristol take responsibility for some parks that are in North Somerset and South Gloucestershire.

To make this work, the Bristol body is setup to cover North Somerset and South Gloucestershire
as well as Bristol. Then method decides which body or bodies to use based on the passed in bodies
and whether the report is in a park.

=cut

sub munge_overlapping_asset_bodies {
    my ($self, $bodies) = @_;

    my $all_areas = $self->{c}->stash->{all_areas};

    if (grep ($self->council_area_id->[0] == $_, keys %$all_areas)) {
        # We are in the Bristol area so carry on as normal
        return;
    } elsif ($self->check_report_is_on_cobrand_asset) {
        # We are not in a Bristol area but the report is in a park that Bristol is responsible for,
        # so only show Bristol categories.
        %$bodies = map { $_->id => $_ } grep { $_->name eq $self->council_name } values %$bodies;
    } else {
        # We are not in a Bristol area and the report is not in a park that Bristol is responsible for,
        # so only show other categories.
        %$bodies = map { $_->id => $_ } grep { $_->name ne $self->council_name } values %$bodies;
    }
}

sub check_report_is_on_cobrand_asset {
    my ($self) = @_;

    # We're only interested in these two parks that lie partially outside of Bristol.
    my @relevant_parks_site_codes = (
        'ASHTCOES', # Ashton Court Estate
        'STOKPAES', # Stoke Park Estate
    );

    my $park = $self->_park_for_point(
        $self->{c}->stash->{latitude},
        $self->{c}->stash->{longitude}
    );
    return 0 unless $park;

    return grep { $_ eq $park->{site_code} } @relevant_parks_site_codes;
}

sub _park_for_point {
    my ( $self, $lat, $lon ) = @_;

    my ($x, $y) = Utils::convert_latlon_to_en($lat, $lon, 'G');

    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    my $cfg = {
        url => "https://$host/mapserver/bristol",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "parks",
        filter => "<Filter><Contains><PropertyName>Geometry</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Contains></Filter>",
        outputformat => 'GML3',
    };

    my $features = $self->_fetch_features($cfg, $x, $y, 1);
    my $park = $features->[0];

    return { site_code => $park->{"ms:parks"}->{"ms:SITE_CODE"} } if $park;
}

1;
