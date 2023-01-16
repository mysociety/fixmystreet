package FixMyStreet::Cobrand::Sutton;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use Moo;
with 'FixMyStreet::Roles::CobrandSLWP';
use Digest::SHA qw(sha1_hex);

sub council_area_id { return 2498; }
sub council_area { return 'Sutton'; }
sub council_name { return 'Sutton Council'; }
sub council_url { return 'sutton'; }

sub admin_user_domain { ('kingston.gov.uk', 'sutton.gov.uk') }

sub dashboard_extra_bodies {
    my $kingston = FixMyStreet::Cobrand::Kingston->new->body;
    return $kingston;
}

sub waste_on_the_day_criteria {
    my ($self, $completed, $state, $now, $row) = @_;

    return unless $now->hour < 18;
    if ($state eq 'Outstanding' || $state eq 'Allocated') {
        $row->{next} = $row->{last};
        $row->{next}{state} = 'In progress';
        delete $row->{last};
    }
    $row->{report_allowed} = 0; # No reports pre-6pm, completed or not
    if ($row->{last}) {
        # Prevent showing collected time until reporting is allowed
        $row->{last}{completed} = 0;
    }
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'paye';
}

has lpi_value => ( is => 'ro', default => 'SUTTON' );

sub waste_payment_ref_council_code { "LBS" }

sub waste_garden_allow_cancellation { 'staff' }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return "$base/bin-green-brown-lid" if $container == 26 || $container == 27;
        return "";
    }
    if (my $container = $unit->{request_containers}[0]) {
        return "$base/caddy-brown-large" if $container == 24;
    }
    my $service_id = $unit->{service_id};
    if ($service_id == 2243 && $unit->{schedule} =~ /fortnight/i) {
        # Communal fortnightly is a wheelie bin, not a large bin
        return "$base/bin-brown";
    }
    my $images = {
        2238 => "$base/bin-brown", # refuse
        2239 => "$base/caddy-brown-large", # food
        2240 => "$base/bin-green", # paper and card
        2241 => "$base/box-green-mix", # dry mixed
        2242 => "$base/sack-clear-red", # domestic refuse bag
        2243 => "$base/large-communal-grey-black-lid", # Communal refuse
        2246 => "$base/sack-clear-blue", # domestic recycling bag
        2248 => "$base/bin-brown", # Communal food
        2249 => "$base/bin-grey-blue-lid-recycling", # Communal paper
        2250 => "$base/large-communal-green", # Communal recycling
        2632 => "$base/sack-clear", # domestic paper bag
    };
    return $images->{$service_id};
}

sub garden_waste_cc_munge_form_details {
    my ($self, $c) = @_;

    my $sha_passphrase = $self->feature('payment_gateway')->{sha_passphrase};

    $c->stash->{payment_amount} = $c->stash->{amount} * 100;

    my $url = $c->uri_for(
        'pay_complete',
        $c->stash->{report}->id,
        $c->stash->{report}->get_extra_metadata('redirect_id')
    );

    $c->stash->{redirect_url} = $url;

    my $form_params = {
        'PSPID' => $c->stash->{payment_details}->{pspid},
        'ORDERID' => $c->stash->{reference},
        'AMOUNT' => $c->stash->{payment_amount},
        'CURRENCY' => 'GBP',
        'LANGUAGE' => 'en_GB',
        'CN' => $c->stash->{first_name} . " " . $c->stash->{last_name},
        'EMAIL' => $c->stash->{email},
        'OWNERZIP' => $c->stash->{postcode},
        'OWNERADDRESS' => $c->stash->{address1},
        'OWNERCTY' => 'UK',
        'OWNERTOWN' => $c->stash->{town},
        'OWNERTELNO' => $c->stash->{phone},
        'ACCEPTURL' => $url,
        'DECLINEURL' => $url,
        'EXCEPTIONURL' => $url,
        'CANCELURL' => $url,
    };

    my $sha = $self->garden_waste_generate_sig( $form_params, $sha_passphrase );
    $c->stash->{cc_sha} = $sha;
}

sub garden_waste_generate_sig {
    my ($self, $params, $passphrase) = @_;

    my $str = "";
    for my $param ( sort { uc($a) cmp uc($b) } keys %$params ) {
        next unless defined $params->{$param} && length $params->{$param}; # Want any 0s
        $str .= uc($param) . "=" . $params->{$param} . $passphrase;
    }

    my $sha = sha1_hex( $str );
    return uc $sha;
}

sub garden_cc_check_payment_status {
    my ($self, $c, $p) = @_;

    my $passphrase = $self->feature('payment_gateway')->{sha_out_passphrase};
    if ( $passphrase ) {
        my $sha = $c->get_param('SHASIGN');

        my %params = %{$c->req->params};
        delete $params{SHASIGN};
        my $check = $self->garden_waste_generate_sig( \%params, $passphrase );
        if ( $check != $sha ) {
            $c->stash->{error} = "Failed security check";
            return undef;
        }
    }

    my $status = $c->get_param('STATUS');
    if ( $status == 9 ) {
        return $c->get_param('PAYID');
    } else {
        my $error = "Unknown error";
        if ( $status == 1 ) {
            $error = "Payment cancelled";
        } elsif ( $status == 2 ) {
            $error = "Payment declined";
        }
        $c->stash->{error} = $error;
        return undef;
    }
}

1;
