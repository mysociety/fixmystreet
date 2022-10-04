package FixMyStreet::Cobrand::Kingston;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use Moo;
with 'FixMyStreet::Roles::CobrandSLWP';
with 'FixMyStreet::Roles::Bottomline';
with 'FixMyStreet::Roles::SCP';

sub council_area_id { return 2480; }
sub council_area { return 'Kingston'; }
sub council_name { return 'Kingston upon Thames Council'; }
sub council_url { return 'kingston'; }

sub admin_user_domain { ('kingston.gov.uk', 'sutton.gov.uk') }

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'cnp';
}

has lpi_value => ( is => 'ro', default => 'KINGSTON UPON THAMES' );

sub waste_payment_ref_council_code { "RBK" }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return "$base/bin-grey-green-lid-recycling" if $container == 26;
        return "";
    }
    my $service_id = $unit->{service_id};
    my $images = {
        2238 => "$base/bin-black", # refuse
        2239 => "$base/bin-brown", # food
        2240 => "$base/bin-grey-blue-lid-recycling", # paper and card
        2241 => "$base/bin-green", # dry mixed
        2242 => "$base/sack-clear-red", # domestic refuse bag
        2243 => "$base/large-communal-black", # Communal refuse
        2246 => "$base/sack-clear-blue", # domestic recycling bag
        2248 => "$base/bin-brown", # Communal food
        2249 => "$base/bin-grey-green-lid-recycling", # Communal paper
        2250 => "$base/large-communal-green", # Communal recycling
        2632 => "$base/sack-clear", # domestic paper bag
    };
    return $images->{$service_id};
}

sub garden_waste_dd_munge_form_details {
    my ($self, $c) = @_;

    $c->stash->{form_name} = $c->stash->{payment_details}->{form_name};

    if ( $c->stash->{staff_payments_allowed} ) {
        $c->stash->{form_name} = $c->stash->{payment_details}->{staff_form_name};
    }
}

1;
