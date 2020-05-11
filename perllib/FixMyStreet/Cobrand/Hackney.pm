package FixMyStreet::Cobrand::Hackney;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use mySociety::EmailUtil qw(is_valid_email);

sub council_area_id { return 2508; }
sub council_area { return 'Hackney'; }
sub council_name { return 'Hackney Council'; }
sub council_url { return 'hackney'; }
sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Hackney',
        centre => '51.552267,-0.063316',
        bounds => [ 51.519814, -0.104511, 51.577784, -0.016527 ],
    };
}

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
}

sub open311_extra_data {
    my ($self, $row, $h, $extra, $contact) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
        { name => 'category',
          value => $row->category },
    ];

    # Make sure contact 'email' set correctly for Open311
    if (my $sent_to = $row->get_extra_metadata('sent_to')) {
        $row->unset_extra_metadata('sent_to');
        my $code = $sent_to->{$contact->email};
        $contact->email($code) if $code;
    }

    return $open311_only;
}

sub map_type { 'OSM' }

sub default_map_zoom { 5 }

sub admin_user_domain { 'hackney.gov.uk' }

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . $self->admin_user_domain,
        name => 'Anonymous user',
    };
}

sub open311_skip_existing_contact {
    my ($self, $contact) = @_;

    # For Hackney we want the 'protected' flag to prevent any changes to this
    # contact at all.
    return $contact->get_extra_metadata("open311_protect") ? 1 : 0;
}

sub open311_filter_contacts_for_deletion {
    my ($self, $contacts) = @_;

    # Don't delete open311 protected contacts when importing
    return $contacts->search({
        extra => { -not_like => '%T15:open311_protect,I1:1%' },
    });
}

sub lookup_site_code_config {
    my ($self, $type) = @_;
    my $property_map = {
        park => "greenspaces:hackney_park",
        estate => "housing:lbh_estate",
    };
    {
        buffer => 3, # metres
        url => "https://map.hackney.gov.uk/geoserver/wfs",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => $property_map->{$type},
        property => ( $type eq "park" ? "park_id" : "id" ),
        accept_feature => sub { 1 },
        accept_types => { Polygon => 1 },
        outputformat => "json",
    }
}

sub get_body_sender {
    my ( $self, $body, $problem ) = @_;

    my $contact = $body->contacts->search( { category => $problem->category } )->first;

    my $parts = join '\s*', qw(^ park : (.*?) ; estate : (.*?) ; other : (.*?) $);
    my $regex = qr/$parts/i;
    if (my ($park, $estate, $other) = $contact->email =~ $regex) {
        my $to = $other;
        if (my $park_id = $self->lookup_site_code($problem, 'park')) {
            $to = $park;
        } elsif (my $estate_id = $self->lookup_site_code($problem, 'estate')) {
            $to = $estate;
        }
        $problem->set_extra_metadata(sent_to => { $contact->email => $to });
        if (is_valid_email($to)) {
            return { method => 'Email', contact => $contact };
        }
    }
    return $self->SUPER::get_body_sender($body, $problem);
}

# Translate email address to actual delivery address
sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    my $sent_to = $row->get_extra_metadata('sent_to') or return;
    $row->unset_extra_metadata('sent_to');
    for my $recip (@{$params->{To}}) {
        my ($email, $name) = @$recip;
        $recip->[0] = $sent_to->{$email} if $sent_to->{$email};
    }
}

1;
