package FixMyStreet::Cobrand::Bristol;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2561; }
sub council_area { return 'Bristol'; }
sub council_name { return 'Bristol County Council'; }
sub council_url { return 'bristol'; }

sub map_type {
    'Bristol';
}

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

sub get_geocoder {
    return 'OSM'; # use OSM geocoder
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub send_questionnaires {
    return 0;
}

sub categories_restriction {
    my ($self, $rs) = @_;
    # Categories covering the Bristol area have a mixture of Open311 and Email
    # send methods. Bristol only want Open311 categories to be visible on their
    # cobrand, not the email categories from FMS.com. We've set up the
    # Email categories with a devolved send_method, so can identify Open311
    # categories as those which have a blank send_method.
    # Also Highways England categories have a blank send_method.
    return $rs->search( { 'me.send_method' => undef } );
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{always_send_email} = 1;
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    # Bristol returns groups we do not want to use
    $service->{group} = [];

    my %server_set = (easting => 1, northing => 1);
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
    }
}

sub admin_user_domain { 'bristol.gov.uk' }

1;
