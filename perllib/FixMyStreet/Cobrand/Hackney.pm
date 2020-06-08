package FixMyStreet::Cobrand::Hackney;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

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
    my ($self, $row, $h, $extra) = @_;

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

1;
