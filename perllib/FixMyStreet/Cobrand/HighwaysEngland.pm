use utf8;
package FixMyStreet::Cobrand::HighwaysEngland;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub enter_postcode_text { 'Enter a location, road name or postcode' }

sub example_places {
    ['A14, Junction 13’, ‘A1 98.5', 'Newark on Trent']
}

sub allow_photo_upload { 0 }

sub report_form_extras { (
    { name => 'sect_label', required => 0 },
    { name => 'area_name', required => 0 },
    { name => 'road_name', required => 0 },
) }

sub allow_anonymous_reports { 'button' }

sub admin_user_domain { 'highwaysengland.co.uk' }

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . $self->admin_user_domain,
        name => 'Anonymous user',
    };
}

sub updates_disallowed {
    my ($self, $problem) = @_;
    return 1 if $problem->is_fixed || $problem->is_closed;
    return 1 if $problem->get_extra_metadata('closed_updates');
    return 0;
}

1;
