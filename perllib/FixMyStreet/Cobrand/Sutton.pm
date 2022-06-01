package FixMyStreet::Cobrand::Sutton;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use Moo;
with 'FixMyStreet::Roles::CobrandSLWP';

sub council_area_id { return 2498; }
sub council_area { return 'Sutton'; }
sub council_name { return 'Sutton Council'; }
sub council_url { return 'sutton'; }

sub admin_user_domain { ('kingston.gov.uk', 'sutton.gov.uk') }

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'cnp';
}

has lpi_value => ( is => 'ro', default => 'SUTTON' );

sub waste_payment_ref_council_code { "LBS" }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return "$base/bin-green-brown-lid" if $container == 26;
        return "";
    }
    if (my $container = $unit->{request_containers}[0]) {
        #return "$base/caddy-brown-small" if $container == 23;
        return "$base/caddy-brown-large" if $container == 24;
    }
    my $service_id = $unit->{service_id};
    my $images = {
        2238 => "$base/bin-brown", # refuse
        2239 => "$base/caddy-brown-large", # food
        2240 => "$base/bin-green", # paper and card
        2241 => "$base/box-green-mix", # dry mixed
        2243 => "$base/large-communal-black", # Communal refuse
        2248 => "$base/bin-brown", # Communal food
        2249 => "$base/bin-grey-green-lid-recycling", # Communal paper
        2250 => "$base/large-communal-green", # Communal recycling
    };
    return $images->{$service_id};
}

1;
