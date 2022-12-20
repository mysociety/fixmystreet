package FixMyStreet::Cobrand::Brent;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use Moo;
with 'FixMyStreet::Roles::Open311Multi';
with 'FixMyStreet::Roles::CobrandOpenUSRN';

sub council_area_id { return 2488; }
sub council_area { return 'Brent'; }
sub council_name { return 'Brent Council'; }
sub council_url { return 'brent'; }

sub path_to_pin_icons {
    return '/cobrands/brent/images/';
}

sub admin_user_domain { 'brent.gov.uk' }

sub allow_anonymous_reports { 'button' }

sub default_map_zoom { 6 }

sub privacy_policy_url {
    'https://www.brent.gov.uk/the-council-and-democracy/access-to-information/data-protection-and-privacy/brent-privacy-policy'
}

sub get_geocoder { 'OSM' }

sub reopening_disallowed { 1 }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a ' . $self->council_area . ' postcode, or street name';
}

sub disambiguate_location { {
    centre => '51.5585509362304,-0.26781886445231',
    span   => '0.0727325098393763,0.144085171830317',
    bounds => [ 51.52763684136, -0.335577710963202, 51.6003693511994, -0.191492539132886 ],
} }

sub categories_restriction {
    my ($self, $rs) = @_;

    # Brent don't want TfL's River Piers category to appear on their cobrand.
    return $rs->search( { 'me.category' => { '-not_like' => 'River Piers%' } } );
}

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

sub user_from_oidc {
    my ($self, $payload) = @_;

    my $name = join(" ", $payload->{givenName}, $payload->{surname});
    my $email = $payload->{email};

    return ($name, $email);
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;
    $params->{multi_photos} = 1;
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;
    $params->{service_request_id_ext} = $comment->problem->id;
}

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    my $open311_only;
    if ($contact->email =~ /^Symology/) {
        # Reports made via the app probably won't have a NSGRef because we don't
        # display the road layer. Instead we'll look up the closest asset from the
        # WFS service at the point we're sending the report over Open311.
        if (!$row->get_extra_field_value('NSGRef')) {
            if (my $ref = $self->lookup_site_code($row, 'usrn')) {
                $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
            }
        }

        if ($contact->groups->[0] eq 'Drains and gullies') {
            if (my $id = $row->get_extra_field_value('UnitID')) {
                $self->{brent_original_detail} = $row->detail;
                my $detail = $row->detail . "\n\nukey: $id";
                $row->detail($detail);
            }
        }
    }

    push @$open311_only, { name => 'title', value => $row->title };

    return $open311_only;
}

sub open311_extra_data_exclude {
    my ($self, $row, $h, $contact) = @_;

    return ['UnitID'] if $contact->groups->[0] eq 'Drains and gullies';
    return [];
}

sub open311_post_send {
    my ($self, $row) = @_;
    $row->detail($self->{brent_original_detail}) if $self->{brent_original_detail};
}

sub prevent_questionnaire_updating_status { 1 };

1;
