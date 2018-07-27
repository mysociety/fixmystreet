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
sub send_questionnaires { 0 }
sub report_sent_confirmation_email { 1 }

sub example_places {
    return ( 'LN1 1YL', 'Orchard Street, Lincoln' );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Lincolnshire',
        centre => '53.1128371079972,-0.237920757894981',
        span   => '0.976148231905086,1.17860658530345',
        bounds => [ 52.6402179235688, -0.820651304784901, 53.6163661554738, 0.357955280518546 ],
    };
}


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

sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/lincs",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "NSG",
    property => "Site_Code",
    accept_feature => sub { 1 }
} }


sub categories_restriction {
    my ($self, $rs) = @_;
    # Lincolnshire is a two-tier council, but don't want to display
    # all district-level categories on their cobrand - just a couple.
    return $rs->search( { -or => [
        'body.name' => "Lincolnshire County Council",

        # District categories:
        'me.category' => { -in => [
            'Street nameplates',
            'Bench/cycle rack/litter bin/planter',
        ] },
    ] } );
}

sub map_type { 'Lincolnshire' }

1;
