package FixMyStreet::Cobrand::Essex;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2225; }
sub council_area { return 'Essex'; }
sub council_name { return 'Essex County Council'; }
sub council_url { return 'essex'; }
sub is_two_tier { 1 }

sub enable_category_groups { 1 }
sub send_questionnaires { 0 }
sub report_sent_confirmation_email { 1 }

sub admin_user_domain { 'essex.gov.uk' }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an Essex postcode, street name and area, or check an existing report number';
}


sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fixmystreet.essex.gov.uk';
}

sub contact_email {
    my $self = shift;
    return join( '@', 'davea', 'mysociety.org' );
}


sub example_places {
    return ( 'CM1 1QH', 'Market Road, Chelmsford' );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Essex',
        centre => '51.8027764242811,0.581658480707373',
        span   => '0.591912301161777,1.31636184455295',
        bounds => [ 51.5007502321134, -0.0197696242979175, 52.0926625332752, 1.29659222025504 ],
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

    $row->set_extra_fields(@$extra);
}

1;
