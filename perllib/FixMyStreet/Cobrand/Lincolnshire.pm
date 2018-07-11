package FixMyStreet::Cobrand::Lincolnshire;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

sub council_area_id { return 2232; }
sub council_area { return 'Lincolnshire'; }
sub council_name { return 'Lincolnshire County Council'; }
sub council_url { return 'lincolnshire'; }
sub is_two_tier { 1 }

sub enable_category_groups { 1 }

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

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

    $row->set_extra_fields(@$extra);
}

sub process_open311_extras {
    my $self = shift;
    $self->SUPER::process_open311_extras( @_ );

    my $c     = shift;
    my $body  = shift;
    my $extra = shift;

    for my $field (@$extra) {
        if ( $field->{name} =~ /ACCU|PICL/ ) {
            $field->{value} = 'NK';
        }
    }
}

sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.staging.mysociety.org/mapserver/lincs",
    # url => "https://confirmdev.eu.ngrok.io/tilmastaging/mapserver/lincs",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "NSG",
    property => "Site_Code",
    accept_feature => sub { 1 }
} }


sub categories_restriction {
    my ($self, $rs) = @_;
    # Lincolnshire is a two-tier council, but only want to display
    # county-level categories on their cobrand.
    return $rs->search( { 'body.name' => "Lincolnshire County Council" } );
}

sub map_type { 'Lincolnshire' }

1;
