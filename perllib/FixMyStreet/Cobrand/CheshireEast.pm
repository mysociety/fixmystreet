package FixMyStreet::Cobrand::CheshireEast;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { 21069 }
sub council_area { 'Cheshire East' }
sub council_name { 'Cheshire East Council' }
sub council_url { 'cheshireeast' }

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible' || !$self->owns_problem( $p );
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'yellow' if $p->is_in_progress;
    return 'red';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '53.180415,-2.349354',
        bounds => [ 52.947150, -2.752929, 53.387445, -1.974789 ],
    };
}

sub enter_postcode_text {
    'Enter a postcode, or a road and place name';
}

sub admin_user_domain { 'cheshireeast.gov.uk' }

sub get_geocoder { 'OSM' }

sub geocoder_munge_results {
    my ($self, $result) = @_;
    $result->{display_name} = '' unless $result->{display_name} =~ /Cheshire East/;
    $result->{display_name} =~ s/, UK$//;
    $result->{display_name} =~ s/, Cheshire East, North West England, England//;
}

sub map_type { 'CheshireEast' }

sub default_map_zoom { 3 }

sub on_map_default_status { 'open' }

sub abuse_reports_only { 1 }

sub send_questionnaires { 0 }

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
}

sub open311_extra_data {
    my ($self, $row, $h, $extra) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
    ];

    # Reports made via FMS.com or the app probably won't have a site code
    # value because we don't display the adopted highways layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('site_code')) {
        if (my $site_code = $self->lookup_site_code($row)) {
            push @$extra,
                { name => 'site_code',
                value => $site_code };
        }
    }

    return $open311_only;
}

# TODO These values may not be accurate
sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/cheshireeast",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "AdoptedRoads",
    property => "site_code",
    accept_feature => sub { 1 }
} }

sub council_rss_alert_options {
    my $self = shift;
    my $all_areas = shift;
    my $c = shift;

    my %councils = map { $_ => 1 } @{$self->area_types};

    my @options;

    my $body = $self->body;

    my ($council, $ward);
    foreach (values %$all_areas) {
        if ($_->{type} eq 'UTA') {
            $council = $_;
            $council->{id} = $body->id; # Want to use body ID, not MapIt area ID
            $council->{short_name} = $self->short_name( $council );
            ( $council->{id_name} = $council->{short_name} ) =~ tr/+/_/;
        } else {
            $ward = $_;
            $ward->{short_name} = $self->short_name( $ward );
            ( $ward->{id_name} = $ward->{short_name} ) =~ tr/+/_/;
        }
    }

    push @options, {
        type      => 'council',
        id        => sprintf( 'council:%s:%s', $council->{id}, $council->{id_name} ),
        text      => 'All reported problems within the council',
        rss_text  => sprintf( 'RSS feed of problems within %s', $council->{name}),
        uri       => $c->uri_for( '/rss/reports/' . $council->{short_name} ),
    };
    push @options, {
        type     => 'ward',
        id       => sprintf( 'ward:%s:%s:%s:%s', $council->{id}, $ward->{id}, $council->{id_name}, $ward->{id_name} ),
        rss_text => sprintf( 'RSS feed of reported problems within %s ward', $ward->{name}),
        text     => sprintf( 'Reported problems within %s ward', $ward->{name}),
        uri      => $c->uri_for( '/rss/reports/' . $council->{short_name} . '/' . $ward->{short_name} ),
    } if $ward;

    return ( \@options, undef );
}

1;
