package FixMyStreet::Cobrand::ZeroTB;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub enter_postcode_text { return _ ('Enter a nearby street name and area, postal code or district in Delhi'); }

sub country {
    return 'IN';
}

sub disambiguate_location {
    return {
        country => 'in',
        town => 'Delhi',
        bounds => [ 28.404625000000024, 76.838845800000072, 28.884380600000028, 77.347877500000067 ],
    };
}

sub only_authed_can_create { return 1; }
sub allow_photo_display { return 0; }
sub allow_photo_upload{ return 0; }
sub send_questionnaires { return 0; }
sub on_map_default_max_pin_age { return 0; }
sub never_confirm_updates { 1; }
sub include_time_in_update_alerts { 1; }

sub pin_colour {
    return 'clinic';
}

sub path_to_pin_icons {
    return '/cobrands/zerotb/images/';
}

sub get_clinic_list {
    my $self = shift;

    return $self->problems->search({ state => 'confirmed' }, { order_by => 'title' });
}

sub prettify_dt {
    my ( $self, $dt, $type ) = @_;
    $type ||= '';

    if ( $type eq 'alert' ) {
        return $dt->strftime('%H:%M %Y-%m-%d');
    } else {
        return Utils::prettify_dt( $dt, $type );
    }

}

1;

